import * as Asana from 'asana';

export class AlfredFormatter {
  formatTask = (task: Asana.resources.Tasks.Type) => {
    const memberships = task.memberships || [];

    const project = memberships[0]?.project;

    let checkmark = '';
    if (task.completed) {
      checkmark = '✓ ';
    }

    let membership = '';

    if (task.parent != null) {
      if (task.parent.name == null) {
        throw new Error('Task parent name required to format!');
      }
      membership += ` / ${task.parent.name}`;
    }
    if (project != null) {
      membership += ` (${project.name})`;
    }

    if (task.name == null) {
      throw new Error('Task name required to format!');
    }
    return `${checkmark}${task.name}${membership}`;
  };

  escapeDescriptionPlainText = (text: string) => text;
}
