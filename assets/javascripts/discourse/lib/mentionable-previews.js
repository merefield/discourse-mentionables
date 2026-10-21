import { applyValueTransformer } from "discourse/lib/transformer";
import Site from "discourse/models/site";
import MentionablePreview from "../components/mentionable-preview.gjs";
import { decorateMentionableLabel } from "./mentionable-label.js";

export function decorateMentionablePreviews(element, helper, tooltip) {
  const cleanups = [];
  const items = Site.current().mentionable_items || [];

  for (const anchor of element.querySelectorAll("a.mentionable-item")) {
    const item = items.find(
      (candidate) =>
        candidate.url === anchor.getAttribute("href") &&
        (!anchor.dataset.mentionableSlug ||
          candidate.slug === anchor.dataset.mentionableSlug)
    );
    if (!item) {
      continue;
    }
    const label = anchor.querySelector("span");
    if (label) {
      decorateMentionableLabel(label, item);
    }

    const clickToPreview = applyValueTransformer(
      "mentionables-click-to-preview",
      false,
      { item }
    );
    const instance = tooltip.register(anchor, {
      identifier: "mentionables-preview",
      ariaLabel: item.name,
      component: MentionablePreview,
      data: {
        ...item,
        topicId: helper?.model?.topic_id,
        categoryId: helper?.model?.topic?.category_id,
      },
      interactive: true,
      hoverGracePeriod: 300,
      maxWidth: 600,
      triggers: clickToPreview
        ? ["click"]
        : { desktop: ["hover", "focus"], mobile: [] },
      untriggers: clickToPreview
        ? ["click"]
        : { desktop: ["hover", "focus"], mobile: [] },
    });
    const onClick = (event) => {
      if (
        clickToPreview &&
        !event.ctrlKey &&
        !event.metaKey &&
        !event.shiftKey &&
        !event.altKey &&
        event.button === 0
      ) {
        event.preventDefault();
        event.stopPropagation();
      }
    };
    // Run before Discourse's delegated link tracking and navigation handlers.
    anchor.addEventListener("click", onClick);
    cleanups.push(() => {
      anchor.removeEventListener("click", onClick);
      instance.destroy();
    });
  }

  return () => cleanups.forEach((cleanup) => cleanup());
}
