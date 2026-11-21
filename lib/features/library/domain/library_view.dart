/// Vistas principales de la Biblioteca.
enum LibraryView {
  all('Todas', 'Vista General'),
  albums('Álbumes', 'Agrupado por álbum'),
  artists('Artistas', 'Agrupado por artista'),
  folders('Carpetas', 'Jerarquía real de tu almacenamiento');

  const LibraryView(this.label, this.description);

  final String label;
  final String description;

  String get fullLabel => switch (this) {
    LibraryView.all => 'Todas (Vista General)',
    _ => label,
  };
}
