import { EditorView } from "@codemirror/view";

export const editorTheme = EditorView.theme({
  "&": {
    fontFamily: '"IBM Plex Mono", monospace',
    fontSize: "12.5px",
    background: "transparent",
  },
  ".cm-content": { padding: "0" },
  ".cm-line": { padding: "0" },
  ".cm-focused": { outline: "none" },
  ".cm-gutters": { display: "none" },
  ".cm-activeLine": { background: "transparent" },
  ".cm-cursor": { borderLeftColor: "#F27345" },
  ".cm-selectionBackground": { background: "#4889C720 !important" },
});
