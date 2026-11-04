/// Page sections; each has a clean URL handled by go_router.
enum Section {
  overview('/', 'Overview'),
  leadership('/leadership', 'Academic Leadership'),
  research('/research', 'Research & Publications'),
  impact('/impact', 'Statistical Impact'),
  gallery('/gallery', 'Photo Gallery'),
  teaching('/teaching', 'Supervision & Teaching'),
  contact('/contact', 'Contact');

  const Section(this.path, this.label);
  final String path, label;

  static Section fromPath(String path) =>
      values.firstWhere((s) => s.path == path, orElse: () => Section.overview);
}
