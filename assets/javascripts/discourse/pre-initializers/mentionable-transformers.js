import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  name: "mentionable-transformers",
  before: "freeze-valid-transformers",

  initialize() {
    withPluginApi((api) => {
      api.addValueTransformerName("mentionables-item-label");
      api.addValueTransformerName("mentionables-click-to-preview");
      api.addValueTransformerName("mentionables-table-columns");
    });
  },
};
