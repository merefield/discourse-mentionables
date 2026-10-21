import { schedule } from "@ember/runloop";
import { registerAdminPluginConfigNav } from "discourse/lib/admin-plugin-config-nav";
import { bind } from "discourse/lib/decorators";
import { withPluginApi } from "discourse/lib/plugin-api";
import MentionableAutocomplete from "../components/mentionable-autocomplete.gjs";
import { searchMentionableItem } from "../lib/mentionable-item-search.js";
import { linkSeenMentionableItems } from "../lib/mentionable-items-preview-styling.js";
import { decorateMentionablePreviews } from "../lib/mentionable-previews.js";
import { mentionablesTableSkeleton } from "../lib/mentionables-table.js";

export default {
  name: "mentionable-items",
  initialize(container) {
    registerAdminPluginConfigNav("discourse-mentionables", [
      { label: "mentionables.title", route: "adminPlugins.show.mentionables" },
    ]);
    const siteSettings = container.lookup("service:site-settings");
    if (!siteSettings.mentionables_enabled) {
      return;
    }
    let activeAutocomplete;

    withPluginApi((api) => {
      api.registerRichEditorExtension({
        parse: {
          mentionable_open() {
            return true;
          },
          mentionable_close() {
            return true;
          },
        },
      });
      api.modifyClass(
        "component:composer-editor",
        (Superclass) =>
          class extends Superclass {
            @bind
            setupEditor(textManipulation) {
              const cleanup = super.setupEditor(...arguments);
              const autocomplete = textManipulation.autocomplete({
                component: MentionableAutocomplete,
                key: "+",
                dataSource: (term) =>
                  /\s/.test(term)
                    ? []
                    : searchMentionableItem(term, siteSettings),
                transformComplete: (item) => item.slug,
                triggerRule: async () =>
                  !(await textManipulation.inCodeBlock()),
              });
              activeAutocomplete = autocomplete;
              return () => {
                if (activeAutocomplete === autocomplete) {
                  activeAutocomplete = null;
                }
                cleanup?.();
              };
            }
          }
      );
      api.decorateCookedElement(
        (element) => linkSeenMentionableItems(element, siteSettings),
        {
          id: "mentionable-items",
          onlyStream: false,
        }
      );
      api.decorateCookedElement(
        (element, helper) =>
          decorateMentionablePreviews(
            element,
            helper,
            container.lookup("service:tooltip")
          ),
        { id: "mentionable-previews", onlyStream: true }
      );
      api.onToolbarCreate((toolbar) => {
        if (api.getCurrentUser()?.admin) {
          toolbar.addButton({
            id: "insert-mentionables-table",
            group: "extras",
            icon: "table",
            title: "mentionables.composer.insert_table.title",
            perform: (event) => event.addText(mentionablesTableSkeleton()),
          });
        }
        toolbar.addButton({
          id: "insert-mentionable",
          group: "extras",
          icon: siteSettings.mentionables_composer_button_icon,
          title: "mentionables.composer.insert.title",
          perform: (event) => {
            // Rich-editor toolbar text is parsed as Markdown, where a bare + is a list marker.
            event.addText(event.commands ? "\\+" : "+");
            schedule("afterRender", () =>
              activeAutocomplete?.performAutocomplete()
            );
          },
        });
      });
    });
  },
};
