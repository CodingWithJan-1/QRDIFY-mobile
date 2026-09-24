enum PortalRole {
  student,
  parent;

  String get label => switch (this) {
    PortalRole.student => 'Student',
    PortalRole.parent => 'Parent',
  };
}
