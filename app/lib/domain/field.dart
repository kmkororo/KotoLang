/// Fields: where in the learner's life a scene happens.
///
/// Four come with the app — work, travel, school, everyday — and the learner
/// can add their own, which live as unlocked realms. Every scene belongs to
/// exactly one field: the built-ins by kind, the learner's own by the field
/// they were made for. Inside a field the scenes split into the samples and
/// the learner's own, which is the split the tree cares about too.
library;

import '../core/util.dart';
import 'models.dart';
import 'scene.dart';

/// The fields that ship with the app, in the order they are shown.
const builtinFieldIds = ['work', 'travel', 'school', 'daily'];

/// The field a scene falls into when it was never told one: the scenes made
/// before fields existed.
const defaultFieldId = 'daily';

class Field {
  final String id;
  final String label;

  /// One of the four that come with the app, as opposed to one the learner
  /// added.
  final bool builtin;
  const Field({required this.id, required this.label, this.builtin = false});
}

/// The field of [scene]: the built-in kind, the field it was made for, or the
/// default for a scene that predates fields.
String fieldOf(Scene scene) => scene.realmId ?? defaultFieldId;

/// Every field the learner can use: the four built-ins, labelled by
/// [labelOf], followed by their own unlocked areas. Locked areas the AI once
/// suggested stay out until they are unlocked.
List<Field> fieldsFrom(List<Realm> realms, String Function(String id) labelOf) {
  // An area the AI once suggested under the same name as a built-in field
  // ("Work", "旅行") is that field, not a second one beside it.
  final taken = {
    for (final id in builtinFieldIds) ...{normKey(id), normKey(labelOf(id))},
    normKey('everyday'),
  };
  return [
    for (final id in builtinFieldIds) Field(id: id, label: labelOf(id), builtin: true),
    for (final r in realms)
      if (r.unlocked &&
          !builtinFieldIds.contains(r.id) &&
          !taken.contains(normKey(r.name)) &&
          !taken.contains(normKey(r.label)))
        Field(id: r.id, label: r.label),
  ];
}

/// The scenes of one field, split the way the field screen shows them.
({List<Scene> samples, List<Scene> own}) splitField(List<Scene> scenes, String fieldId) {
  final inField = [for (final s in scenes) if (!s.disabled && fieldOf(s) == fieldId) s];
  return (
    samples: [for (final s in inField) if (s.isBuiltin) s],
    own: [for (final s in inField) if (!s.isBuiltin) s],
  );
}

/// The areas the AI suggested that are not open yet: shown priced in the
/// field list, so making scenes for one is a matter of opening it.
List<Field> lockedFieldsFrom(List<Realm> realms, String Function(String id) labelOf) {
  final taken = {
    for (final id in builtinFieldIds) ...{normKey(id), normKey(labelOf(id))},
    normKey('everyday'),
  };
  return [
    for (final r in realms)
      if (!r.unlocked &&
          !builtinFieldIds.contains(r.id) &&
          !taken.contains(normKey(r.name)) &&
          !taken.contains(normKey(r.label)))
        Field(id: r.id, label: r.label),
  ];
}
