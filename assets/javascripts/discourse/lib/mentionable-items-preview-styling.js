import { lookupCache } from "pretty-text/oneboxer-cache";
import domFromString from "discourse/lib/dom-from-string";
import Site from "discourse/models/site";
import { decorateMentionableLabel } from "./mentionable-label.js";

function standalone(span) {
  if (
    span.parentElement?.tagName !== "P" ||
    span.closest("blockquote, li, td, th")
  ) {
    return false;
  }
  return ["previousSibling", "nextSibling"].every((direction) => {
    let node = span[direction];
    while (node?.nodeType === Node.TEXT_NODE && !node.textContent.trim()) {
      node = node[direction];
    }
    return !node || node.nodeName === "BR";
  });
}

export function linkSeenMentionableItems(element, siteSettings) {
  const items = Site.current().mentionable_items || [];
  let loadedOneboxes = element.querySelectorAll(
    "aside.onebox, a.loading-onebox, a.inline-onebox"
  ).length;
  for (const span of element.querySelectorAll("span.mentionable-item")) {
    const item = items.find(
      (candidate) => candidate.slug === span.textContent.slice(1)
    );
    if (!item || !/^https?:\/\//i.test(item.url)) {
      continue;
    }
    const anchor = document.createElement("a");
    anchor.href = item.url;
    const isStandalone = standalone(span);
    anchor.className = isStandalone ? "onebox" : "mentionable-item";
    anchor.target = "_blank";
    anchor.rel = "nofollow ugc noopener";
    const label = document.createElement("span");
    label.textContent = item.name;
    if (!isStandalone) {
      anchor.dataset.mentionableSlug = item.slug;
      decorateMentionableLabel(label, item);
    }
    anchor.append(label);
    span.replaceWith(anchor);

    // These anchors are created after Markdown's cached-onebox replacement.
    // Leave uncached anchors for the composer's contextual, queued loader.
    if (isStandalone && loadedOneboxes < siteSettings.max_oneboxes_per_post) {
      const cached = lookupCache(item.url);
      if (cached) {
        anchor.replaceWith(...domFromString(cached));
        loadedOneboxes++;
      }
    }
  }
}
