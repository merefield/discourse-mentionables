import Site from "discourse/models/site";

export function searchMentionableItem(term, siteSettings) {
  const query = term.toLowerCase();
  return (Site.current().mentionable_items || [])
    .filter((item) =>
      [item.slug, item.name].some((value) =>
        value?.toLowerCase().includes(query)
      )
    )
    .slice(0, siteSettings.mentionables_autocomplete_limit);
}
