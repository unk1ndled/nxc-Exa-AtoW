{ pkgs }:

let
  # shared helpers injected into every script
  commonLib = ''
    _die()  { echo -e "\033[1;31m[error]\033[0m $*" >&2; exit 1; }
    _ok()   { echo -e "\033[1;32m[ok]\033[0m $*" >&2; }
    _info() { echo -e "\033[1;34m[..]\033[0m $*" >&2; }
    _warn() { echo -e "\033[1;33m[warn]\033[0m $*" >&2; }
    _check_token() {
      [ -n "''${EBUFFER_TOKEN:-}" ] || _die "EBUFFER_TOKEN is not set — run: eval \$(eb-login)"
    }
    _api() { echo "''${EBAPI_URL:-http://localhost:''${EBAPI_PORT:-8000}}/api/v1"; }
    _curl() {
      ${pkgs.curl}/bin/curl --silent --show-error --fail-with-body "$@"
    }
    _curl_check() {
      local OUT CODE
      OUT=$(${pkgs.curl}/bin/curl --silent --show-error -w '\n%{http_code}' "$@")
      CODE=$(echo "$OUT" | tail -n1)
      BODY=$(echo "$OUT" | head -n-1)
      if [ "$CODE" -lt 200 ] || [ "$CODE" -ge 300 ]; then
        echo "$BODY" | ${pkgs.jq}/bin/jq -r '
          if type == "object" then
            "HTTP \(env.CODE) — " + (.detail // .message // .error // tostring)
          else "HTTP \(env.CODE)"
          end' 2>/dev/null || echo "HTTP $CODE"
        return 1
      fi
      echo "$BODY"
    }
  '';

  eb-login = pkgs.writeShellScriptBin "eb-login" ''
    set -euo pipefail
    ${commonLib}
    USER=''${1:-admin}
    PASS=''${2:-admin}
    API=$(_api)

    _info "Authenticating as '$USER' at $API"

    RESP=$(${pkgs.curl}/bin/curl --silent --show-error -w '\n%{http_code}' \
      -H 'Content-Type: application/json' \
      --data "{\"username\":\"$USER\",\"password\":\"$PASS\"}" \
      "$API/auth/login") || _die "Request failed — is the server running at $API?"

    CODE=$(echo "$RESP" | tail -n1)
    BODY=$(echo "$RESP" | head -n-1)

    case "$CODE" in
      401) _die "Wrong username or password." ;;
      404) _die "Auth endpoint not found — check EBAPI_URL." ;;
      000) _die "Could not connect to $API — server unreachable." ;;
      2*)  ;;
      *)   _die "Unexpected HTTP $CODE:"; echo "$BODY" | ${pkgs.jq}/bin/jq . >&2; exit 1 ;;
    esac

    ERROR_LEVEL=$(echo "$BODY" | ${pkgs.jq}/bin/jq -r '.error_level // empty')
    if [ -z "$ERROR_LEVEL" ] || [ "$ERROR_LEVEL" != "0" ]; then
      MSG=$(echo "$BODY" | ${pkgs.jq}/bin/jq -r '.message // .detail // .error // "unknown error"')
      _die "Login rejected by server: $MSG"
    fi

    TOKEN=$(echo "$BODY" | ${pkgs.jq}/bin/jq -r '.token')
    _ok "Logged in — token: ''${TOKEN:0:16}…"
    echo "export EBUFFER_TOKEN='$TOKEN'"
    echo "export EBUFFER_AUTH_HEADER='Authorization: Bearer $TOKEN'"
  '';

  eb-create = pkgs.writeShellScriptBin "eb-create" ''
    set -euo pipefail
    ${commonLib}
    _check_token
    API=$(_api)
    LIFESPAN=''${1:-40}
    SIZE=''${2:-2000000000}

    _info "Creating buffer (lifespan=''${LIFESPAN}s, size=''${SIZE}B)"

    RESP=$(_curl_check \
      -H 'Content-Type: application/json' \
      -H "Authorization: Bearer $EBUFFER_TOKEN" \
      --data "{\"lifespan\": $LIFESPAN, \"reserved_size\": $SIZE}" \
      "$API/eph_buffer") || _die "Failed to create buffer: $RESP"

    UUID=$(echo "$RESP" | ${pkgs.jq}/bin/jq -r '.uuid')
    _ok "Created buffer $UUID"
    echo "$RESP" | ${pkgs.jq}/bin/jq .
  '';

  eb-list = pkgs.writeShellScriptBin "eb-list" ''
    set -euo pipefail
    ${commonLib}
    _check_token
    API=$(_api)

    COUNT_RESP=$(_curl_check \
      -H "Authorization: Bearer $EBUFFER_TOKEN" \
      "$API/eph_buffer?count=true") || _die "Failed to fetch count: $COUNT_RESP"
    _info "Total buffers: $(echo "$COUNT_RESP" | ${pkgs.jq}/bin/jq -r '.count // .')"

    RESP=$(_curl_check \
      -H "Authorization: Bearer $EBUFFER_TOKEN" \
      "$API/eph_buffer") || _die "Failed to list buffers: $RESP"

    N=$(echo "$RESP" | ${pkgs.jq}/bin/jq 'if type=="array" then length else 1 end')
    [ "$N" -eq 0 ] && _warn "No buffers found." || echo "$RESP" | ${pkgs.jq}/bin/jq .
  '';

  eb-testc = pkgs.writeShellScriptBin "eb-testc" ''
    set -euo pipefail
    ${commonLib}
    _check_token
    API=$(_api)
    FILE=''${1:?Usage: eb-testc <file>}
    [ -f "$FILE" ] || _die "File not found: $FILE"
    AUTH=(-H "Authorization: Bearer $EBUFFER_TOKEN")
    JSON=(-H 'Content-Type: application/json')

    _info "Step 1/4 — Creating buffer"
    UID=$(_curl_check "''${JSON[@]}" "''${AUTH[@]}" \
      --data '{"lifespan": 40, "reserved_size": 2000000000}' \
      "$API/eph_buffer") || _die "Create failed: $UID"
    UID=$(echo "$UID" | ${pkgs.jq}/bin/jq -r '.uuid')
    _ok "Buffer: $UID"

    _info "Step 2/4 — Uploading $FILE ($(du -sh "$FILE" | cut -f1))"
    UP=$(_curl_check "''${AUTH[@]}" -X PUT \
      "$API/eph_buffer/$UID/data" -T "$FILE") || _die "Upload failed: $UP"
    STATE=$(echo "$UP" | ${pkgs.jq}/bin/jq -r '.state // "unknown"')
    _ok "Upload complete — state: $STATE"

    _info "Step 3/4 — Checking status"
    STATUS=$(_curl_check "''${JSON[@]}" "''${AUTH[@]}" \
      "$API/eph_buffer/$UID") || _die "Status check failed: $STATUS"
    echo "$STATUS" | ${pkgs.jq}/bin/jq .

    _info "Step 4/4 — Downloading and verifying"
    OUTFILE=$(mktemp)
    trap 'rm -f "$OUTFILE"' EXIT
    CODE=$(${pkgs.curl}/bin/curl --silent --show-error "''${AUTH[@]}" -X GET \
      "$API/eph_buffer/$UID/data" -o "$OUTFILE" -w "%{http_code}")
    [ "$CODE" = "200" ] || {
      ${pkgs.jq}/bin/jq -r '"Download failed (HTTP \(env.CODE)): " + (.detail // .message // tostring)' \
        < "$OUTFILE" 2>/dev/null || echo "Download failed (HTTP $CODE)" >&2
      exit 1
    }

    SRC=$(cksum "$FILE"); DL=$(cksum "$OUTFILE")
    SRC_HASH=$(echo "$SRC" | awk '{print $1}')
    DL_HASH=$(echo "$DL"  | awk '{print $1}')
    if [ "$SRC_HASH" = "$DL_HASH" ]; then
      _ok "Checksums match ($SRC_HASH)"
    else
      _die "Checksum mismatch!\n  source:     $SRC\n  downloaded: $DL"
    fi
  '';

  eb-testd = pkgs.writeShellScriptBin "eb-testd" ''
    set -euo pipefail
    ${commonLib}
    _check_token
    API=$(_api)
    FILE=''${1:-tests/client/example.txt}
    COUNT=''${2:-500}
    [ -f "$FILE" ] || _die "File not found: $FILE"
    AUTH=(-H "Authorization: Bearer $EBUFFER_TOKEN")
    JSON=(-H 'Content-Type: application/json')

    declare -a UUIDS=()
    FAILS=0

    _info "Phase 1/3 — Creating $COUNT buffers (sequential)"
    for i in $(seq 1 "$COUNT"); do
      UID=$(_curl_check "''${AUTH[@]}" "''${JSON[@]}" \
        "$API/eph_buffer?blocking=true" -X POST \
        -d '{"reserved_size":200, "lifespan":30}' 2>/dev/null | ${pkgs.jq}/bin/jq -cr .uuid) || {
        _warn "Create #$i failed, skipping"
        FAILS=$((FAILS+1)); continue
      }
      UUIDS+=("$UID")
      [ $((i % 100)) -eq 0 ] && _info "  created $i/$COUNT..."
    done
    _ok "Created ''${#UUIDS[@]}/$COUNT buffers ($FAILS failures)"

    _info "Phase 2/3 — Uploading in parallel"
    for uid in "''${UUIDS[@]}"; do
      _curl_check "''${AUTH[@]}" "$API/eph_buffer/$uid/data" -X PUT -T "$FILE" \
        > /dev/null 2>&1 &
    done
    wait
    _ok "Uploads complete"

    _info "Phase 3/3 — Downloading in parallel"
    { time (
      for uid in "''${UUIDS[@]}"; do
        _curl_check "''${AUTH[@]}" "$API/eph_buffer/$uid/data" -X GET \
          -o /dev/null 2>&1 &
      done
      wait
    ); } 2>&1 | grep -E '^(real|user|sys)'
    _ok "Downloads complete"
  '';

in
pkgs.symlinkJoin {
  name = "ebhelpers";
  paths = [
    eb-login
    eb-create
    eb-list
    eb-testc
    eb-testd
  ];
}
