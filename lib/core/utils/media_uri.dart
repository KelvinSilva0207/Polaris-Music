/// Normalización shared entre las rutas de [Track] y las URIs de `Media`.
///
/// El constructor de `Media` de media_kit normaliza las barras de Windows en el
/// momento de construir la URI (`C:\Música\canción.mp3` se convierte en
/// `C:/Música/canción.mp3`). Si la capa de dominio compara la cadena original
/// con la URI ya normalizada, la pista no se resuelve. El síntoma más visible
/// era que al terminar una canción con crossfade el reproductor se quedaba sin
/// `currentTrack` (vista vacía) mientras el deck entrante seguía sonando.
///
/// En Linux/macOS las rutas ya usan `/`, así que la función es identidad. Tampoco
/// afecta a URLs de red, que no contienen barras inversas.
String normalizeMediaUri(String value) => value.replaceAll(r'\', '/');
