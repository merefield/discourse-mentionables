import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

export default class MentionablesRoute extends DiscourseRoute {
  model() {
    return ajax("/admin/plugins/mentionables/logs.json");
  }
}
