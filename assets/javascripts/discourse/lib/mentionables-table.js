import { applyValueTransformer } from "discourse/lib/transformer";

export function mentionablesTableSkeleton() {
  const columns = applyValueTransformer("mentionables-table-columns", [
    "name",
    "url",
    "slug",
    "image_url",
  ]);
  const row = (values) => `| ${values.join(" | ")} |`;
  return `\n\n${[
    row(columns),
    row(columns.map(() => "---")),
    row(columns.map(() => "")),
  ].join("\n")}\n\n`;
}
