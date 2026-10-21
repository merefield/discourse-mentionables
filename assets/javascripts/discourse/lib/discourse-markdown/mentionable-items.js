export function setup(helper) {
  helper.allowList(["span.mentionable-item"]);
  helper.registerOptions((options, siteSettings) => {
    options.features["mentionable-items"] = !!siteSettings.mentionables_enabled;
  });
  helper.registerPlugin((md) => {
    md.core.textPostProcess.ruler.push("mentionable-items", {
      matcher: /\+([\p{L}\p{N}](?:[\p{L}\p{N}_.-]{0,198}[\p{L}\p{N}])?)/u,
      onMatch(buffer, matches, state) {
        const open = new state.Token("mentionable_open", "span", 1);
        open.attrs = [["class", "mentionable-item"]];
        const text = new state.Token("text", "", 0);
        text.content = matches[0];
        buffer.push(
          open,
          text,
          new state.Token("mentionable_close", "span", -1)
        );
      },
    });
  });
}
