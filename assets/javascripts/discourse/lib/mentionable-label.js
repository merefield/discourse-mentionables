import { modifier } from "ember-modifier";
import { applyValueTransformer } from "discourse/lib/transformer";

export function decorateMentionableLabel(element, item) {
  applyValueTransformer("mentionables-item-label", element, { item });
}

export const mentionableLabel = modifier((element, [item]) => {
  decorateMentionableLabel(element, item);
});
