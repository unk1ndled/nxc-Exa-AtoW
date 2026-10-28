module.exports = {
  content: ["./index.html", "./src/**/*.{js,jsx,ts,tsx}"],
  theme: {
    extend: {
      fontFamily: {
        mono: ['"IBM Plex Mono"', '"Courier New"', "monospace"],
      },
      colors: {
        paper: "#F6F6F2",
        "paper-alt": "#EEEEE9",
        ink: "#111110",
        muted: "#6B6B65",
        rule: "#CCCCC5",
        accent1: "#F27345",
        accent2: "#4889C7",
      },
      maxWidth: {
        content: "780px",
      },
    },
  },
  plugins: [],
};
