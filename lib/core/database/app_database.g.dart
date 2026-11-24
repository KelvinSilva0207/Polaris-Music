// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $TracksTable extends Tracks with TableInfo<$TracksTable, TrackRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TracksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _artistMeta = const VerificationMeta('artist');
  @override
  late final GeneratedColumn<String> artist = GeneratedColumn<String>(
    'artist',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('Desconocido'),
  );
  static const VerificationMeta _albumMeta = const VerificationMeta('album');
  @override
  late final GeneratedColumn<String> album = GeneratedColumn<String>(
    'album',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('Desconocido'),
  );
  static const VerificationMeta _albumArtistMeta = const VerificationMeta(
    'albumArtist',
  );
  @override
  late final GeneratedColumn<String> albumArtist = GeneratedColumn<String>(
    'album_artist',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _genreMeta = const VerificationMeta('genre');
  @override
  late final GeneratedColumn<String> genre = GeneratedColumn<String>(
    'genre',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _yearMeta = const VerificationMeta('year');
  @override
  late final GeneratedColumn<int> year = GeneratedColumn<int>(
    'year',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _trackNumberMeta = const VerificationMeta(
    'trackNumber',
  );
  @override
  late final GeneratedColumn<int> trackNumber = GeneratedColumn<int>(
    'track_number',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _discNumberMeta = const VerificationMeta(
    'discNumber',
  );
  @override
  late final GeneratedColumn<int> discNumber = GeneratedColumn<int>(
    'disc_number',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _bitrateMeta = const VerificationMeta(
    'bitrate',
  );
  @override
  late final GeneratedColumn<int> bitrate = GeneratedColumn<int>(
    'bitrate',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sampleRateMeta = const VerificationMeta(
    'sampleRate',
  );
  @override
  late final GeneratedColumn<int> sampleRate = GeneratedColumn<int>(
    'sample_rate',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _formatMeta = const VerificationMeta('format');
  @override
  late final GeneratedColumn<String> format = GeneratedColumn<String>(
    'format',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fileSizeMeta = const VerificationMeta(
    'fileSize',
  );
  @override
  late final GeneratedColumn<int> fileSize = GeneratedColumn<int>(
    'file_size',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _artworkPathMeta = const VerificationMeta(
    'artworkPath',
  );
  @override
  late final GeneratedColumn<String> artworkPath = GeneratedColumn<String>(
    'artwork_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('local'),
  );
  static const VerificationMeta _externalIdMeta = const VerificationMeta(
    'externalId',
  );
  @override
  late final GeneratedColumn<String> externalId = GeneratedColumn<String>(
    'external_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _replayGainTrackDbMeta = const VerificationMeta(
    'replayGainTrackDb',
  );
  @override
  late final GeneratedColumn<double> replayGainTrackDb =
      GeneratedColumn<double>(
        'replay_gain_track_db',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _replayGainAlbumDbMeta = const VerificationMeta(
    'replayGainAlbumDb',
  );
  @override
  late final GeneratedColumn<double> replayGainAlbumDb =
      GeneratedColumn<double>(
        'replay_gain_album_db',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _isFavoriteMeta = const VerificationMeta(
    'isFavorite',
  );
  @override
  late final GeneratedColumn<bool> isFavorite = GeneratedColumn<bool>(
    'is_favorite',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_favorite" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _playCountMeta = const VerificationMeta(
    'playCount',
  );
  @override
  late final GeneratedColumn<int> playCount = GeneratedColumn<int>(
    'play_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _skipCountMeta = const VerificationMeta(
    'skipCount',
  );
  @override
  late final GeneratedColumn<int> skipCount = GeneratedColumn<int>(
    'skip_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastPlayedAtMeta = const VerificationMeta(
    'lastPlayedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastPlayedAt = GeneratedColumn<DateTime>(
    'last_played_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<DateTime> addedAt = GeneratedColumn<DateTime>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    path,
    title,
    artist,
    album,
    albumArtist,
    genre,
    year,
    trackNumber,
    discNumber,
    durationMs,
    bitrate,
    sampleRate,
    format,
    fileSize,
    artworkPath,
    source,
    externalId,
    replayGainTrackDb,
    replayGainAlbumDb,
    isFavorite,
    playCount,
    skipCount,
    lastPlayedAt,
    addedAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tracks';
  @override
  VerificationContext validateIntegrity(
    Insertable<TrackRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('artist')) {
      context.handle(
        _artistMeta,
        artist.isAcceptableOrUnknown(data['artist']!, _artistMeta),
      );
    }
    if (data.containsKey('album')) {
      context.handle(
        _albumMeta,
        album.isAcceptableOrUnknown(data['album']!, _albumMeta),
      );
    }
    if (data.containsKey('album_artist')) {
      context.handle(
        _albumArtistMeta,
        albumArtist.isAcceptableOrUnknown(
          data['album_artist']!,
          _albumArtistMeta,
        ),
      );
    }
    if (data.containsKey('genre')) {
      context.handle(
        _genreMeta,
        genre.isAcceptableOrUnknown(data['genre']!, _genreMeta),
      );
    }
    if (data.containsKey('year')) {
      context.handle(
        _yearMeta,
        year.isAcceptableOrUnknown(data['year']!, _yearMeta),
      );
    }
    if (data.containsKey('track_number')) {
      context.handle(
        _trackNumberMeta,
        trackNumber.isAcceptableOrUnknown(
          data['track_number']!,
          _trackNumberMeta,
        ),
      );
    }
    if (data.containsKey('disc_number')) {
      context.handle(
        _discNumberMeta,
        discNumber.isAcceptableOrUnknown(data['disc_number']!, _discNumberMeta),
      );
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    }
    if (data.containsKey('bitrate')) {
      context.handle(
        _bitrateMeta,
        bitrate.isAcceptableOrUnknown(data['bitrate']!, _bitrateMeta),
      );
    }
    if (data.containsKey('sample_rate')) {
      context.handle(
        _sampleRateMeta,
        sampleRate.isAcceptableOrUnknown(data['sample_rate']!, _sampleRateMeta),
      );
    }
    if (data.containsKey('format')) {
      context.handle(
        _formatMeta,
        format.isAcceptableOrUnknown(data['format']!, _formatMeta),
      );
    }
    if (data.containsKey('file_size')) {
      context.handle(
        _fileSizeMeta,
        fileSize.isAcceptableOrUnknown(data['file_size']!, _fileSizeMeta),
      );
    }
    if (data.containsKey('artwork_path')) {
      context.handle(
        _artworkPathMeta,
        artworkPath.isAcceptableOrUnknown(
          data['artwork_path']!,
          _artworkPathMeta,
        ),
      );
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    }
    if (data.containsKey('external_id')) {
      context.handle(
        _externalIdMeta,
        externalId.isAcceptableOrUnknown(data['external_id']!, _externalIdMeta),
      );
    }
    if (data.containsKey('replay_gain_track_db')) {
      context.handle(
        _replayGainTrackDbMeta,
        replayGainTrackDb.isAcceptableOrUnknown(
          data['replay_gain_track_db']!,
          _replayGainTrackDbMeta,
        ),
      );
    }
    if (data.containsKey('replay_gain_album_db')) {
      context.handle(
        _replayGainAlbumDbMeta,
        replayGainAlbumDb.isAcceptableOrUnknown(
          data['replay_gain_album_db']!,
          _replayGainAlbumDbMeta,
        ),
      );
    }
    if (data.containsKey('is_favorite')) {
      context.handle(
        _isFavoriteMeta,
        isFavorite.isAcceptableOrUnknown(data['is_favorite']!, _isFavoriteMeta),
      );
    }
    if (data.containsKey('play_count')) {
      context.handle(
        _playCountMeta,
        playCount.isAcceptableOrUnknown(data['play_count']!, _playCountMeta),
      );
    }
    if (data.containsKey('skip_count')) {
      context.handle(
        _skipCountMeta,
        skipCount.isAcceptableOrUnknown(data['skip_count']!, _skipCountMeta),
      );
    }
    if (data.containsKey('last_played_at')) {
      context.handle(
        _lastPlayedAtMeta,
        lastPlayedAt.isAcceptableOrUnknown(
          data['last_played_at']!,
          _lastPlayedAtMeta,
        ),
      );
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TrackRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TrackRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      artist: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}artist'],
      )!,
      album: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}album'],
      )!,
      albumArtist: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}album_artist'],
      ),
      genre: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}genre'],
      ),
      year: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}year'],
      ),
      trackNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}track_number'],
      ),
      discNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}disc_number'],
      ),
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      )!,
      bitrate: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bitrate'],
      ),
      sampleRate: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sample_rate'],
      ),
      format: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}format'],
      ),
      fileSize: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}file_size'],
      )!,
      artworkPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}artwork_path'],
      ),
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      externalId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}external_id'],
      ),
      replayGainTrackDb: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}replay_gain_track_db'],
      ),
      replayGainAlbumDb: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}replay_gain_album_db'],
      ),
      isFavorite: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_favorite'],
      )!,
      playCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}play_count'],
      )!,
      skipCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}skip_count'],
      )!,
      lastPlayedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_played_at'],
      ),
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}added_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $TracksTable createAlias(String alias) {
    return $TracksTable(attachedDatabase, alias);
  }
}

class TrackRow extends DataClass implements Insertable<TrackRow> {
  final int id;
  final String path;
  final String title;
  final String artist;
  final String album;
  final String? albumArtist;
  final String? genre;
  final int? year;
  final int? trackNumber;
  final int? discNumber;
  final int durationMs;
  final int? bitrate;
  final int? sampleRate;
  final String? format;
  final int fileSize;
  final String? artworkPath;

  /// Origen de la fila: `local` (escaneada) o `download` (módulo online).
  ///
  /// Se usa para distinguir la etiqueta de nube en la biblioteca y para que el
  /// escaneo no elimine descargas que no viven en las carpetas vigiladas.
  final String source;

  /// Identificador en la fuente online (`audius:<id>`), único por descarga.
  final String? externalId;

  /// Ganancia ReplayGain en dB (etiqueta REPLAYGAIN_TRACK_GAIN / APE).
  final double? replayGainTrackDb;
  final double? replayGainAlbumDb;
  final bool isFavorite;
  final int playCount;
  final int skipCount;
  final DateTime? lastPlayedAt;
  final DateTime addedAt;
  final DateTime updatedAt;
  const TrackRow({
    required this.id,
    required this.path,
    required this.title,
    required this.artist,
    required this.album,
    this.albumArtist,
    this.genre,
    this.year,
    this.trackNumber,
    this.discNumber,
    required this.durationMs,
    this.bitrate,
    this.sampleRate,
    this.format,
    required this.fileSize,
    this.artworkPath,
    required this.source,
    this.externalId,
    this.replayGainTrackDb,
    this.replayGainAlbumDb,
    required this.isFavorite,
    required this.playCount,
    required this.skipCount,
    this.lastPlayedAt,
    required this.addedAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['path'] = Variable<String>(path);
    map['title'] = Variable<String>(title);
    map['artist'] = Variable<String>(artist);
    map['album'] = Variable<String>(album);
    if (!nullToAbsent || albumArtist != null) {
      map['album_artist'] = Variable<String>(albumArtist);
    }
    if (!nullToAbsent || genre != null) {
      map['genre'] = Variable<String>(genre);
    }
    if (!nullToAbsent || year != null) {
      map['year'] = Variable<int>(year);
    }
    if (!nullToAbsent || trackNumber != null) {
      map['track_number'] = Variable<int>(trackNumber);
    }
    if (!nullToAbsent || discNumber != null) {
      map['disc_number'] = Variable<int>(discNumber);
    }
    map['duration_ms'] = Variable<int>(durationMs);
    if (!nullToAbsent || bitrate != null) {
      map['bitrate'] = Variable<int>(bitrate);
    }
    if (!nullToAbsent || sampleRate != null) {
      map['sample_rate'] = Variable<int>(sampleRate);
    }
    if (!nullToAbsent || format != null) {
      map['format'] = Variable<String>(format);
    }
    map['file_size'] = Variable<int>(fileSize);
    if (!nullToAbsent || artworkPath != null) {
      map['artwork_path'] = Variable<String>(artworkPath);
    }
    map['source'] = Variable<String>(source);
    if (!nullToAbsent || externalId != null) {
      map['external_id'] = Variable<String>(externalId);
    }
    if (!nullToAbsent || replayGainTrackDb != null) {
      map['replay_gain_track_db'] = Variable<double>(replayGainTrackDb);
    }
    if (!nullToAbsent || replayGainAlbumDb != null) {
      map['replay_gain_album_db'] = Variable<double>(replayGainAlbumDb);
    }
    map['is_favorite'] = Variable<bool>(isFavorite);
    map['play_count'] = Variable<int>(playCount);
    map['skip_count'] = Variable<int>(skipCount);
    if (!nullToAbsent || lastPlayedAt != null) {
      map['last_played_at'] = Variable<DateTime>(lastPlayedAt);
    }
    map['added_at'] = Variable<DateTime>(addedAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  TracksCompanion toCompanion(bool nullToAbsent) {
    return TracksCompanion(
      id: Value(id),
      path: Value(path),
      title: Value(title),
      artist: Value(artist),
      album: Value(album),
      albumArtist: albumArtist == null && nullToAbsent
          ? const Value.absent()
          : Value(albumArtist),
      genre: genre == null && nullToAbsent
          ? const Value.absent()
          : Value(genre),
      year: year == null && nullToAbsent ? const Value.absent() : Value(year),
      trackNumber: trackNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(trackNumber),
      discNumber: discNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(discNumber),
      durationMs: Value(durationMs),
      bitrate: bitrate == null && nullToAbsent
          ? const Value.absent()
          : Value(bitrate),
      sampleRate: sampleRate == null && nullToAbsent
          ? const Value.absent()
          : Value(sampleRate),
      format: format == null && nullToAbsent
          ? const Value.absent()
          : Value(format),
      fileSize: Value(fileSize),
      artworkPath: artworkPath == null && nullToAbsent
          ? const Value.absent()
          : Value(artworkPath),
      source: Value(source),
      externalId: externalId == null && nullToAbsent
          ? const Value.absent()
          : Value(externalId),
      replayGainTrackDb: replayGainTrackDb == null && nullToAbsent
          ? const Value.absent()
          : Value(replayGainTrackDb),
      replayGainAlbumDb: replayGainAlbumDb == null && nullToAbsent
          ? const Value.absent()
          : Value(replayGainAlbumDb),
      isFavorite: Value(isFavorite),
      playCount: Value(playCount),
      skipCount: Value(skipCount),
      lastPlayedAt: lastPlayedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastPlayedAt),
      addedAt: Value(addedAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory TrackRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TrackRow(
      id: serializer.fromJson<int>(json['id']),
      path: serializer.fromJson<String>(json['path']),
      title: serializer.fromJson<String>(json['title']),
      artist: serializer.fromJson<String>(json['artist']),
      album: serializer.fromJson<String>(json['album']),
      albumArtist: serializer.fromJson<String?>(json['albumArtist']),
      genre: serializer.fromJson<String?>(json['genre']),
      year: serializer.fromJson<int?>(json['year']),
      trackNumber: serializer.fromJson<int?>(json['trackNumber']),
      discNumber: serializer.fromJson<int?>(json['discNumber']),
      durationMs: serializer.fromJson<int>(json['durationMs']),
      bitrate: serializer.fromJson<int?>(json['bitrate']),
      sampleRate: serializer.fromJson<int?>(json['sampleRate']),
      format: serializer.fromJson<String?>(json['format']),
      fileSize: serializer.fromJson<int>(json['fileSize']),
      artworkPath: serializer.fromJson<String?>(json['artworkPath']),
      source: serializer.fromJson<String>(json['source']),
      externalId: serializer.fromJson<String?>(json['externalId']),
      replayGainTrackDb: serializer.fromJson<double?>(
        json['replayGainTrackDb'],
      ),
      replayGainAlbumDb: serializer.fromJson<double?>(
        json['replayGainAlbumDb'],
      ),
      isFavorite: serializer.fromJson<bool>(json['isFavorite']),
      playCount: serializer.fromJson<int>(json['playCount']),
      skipCount: serializer.fromJson<int>(json['skipCount']),
      lastPlayedAt: serializer.fromJson<DateTime?>(json['lastPlayedAt']),
      addedAt: serializer.fromJson<DateTime>(json['addedAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'path': serializer.toJson<String>(path),
      'title': serializer.toJson<String>(title),
      'artist': serializer.toJson<String>(artist),
      'album': serializer.toJson<String>(album),
      'albumArtist': serializer.toJson<String?>(albumArtist),
      'genre': serializer.toJson<String?>(genre),
      'year': serializer.toJson<int?>(year),
      'trackNumber': serializer.toJson<int?>(trackNumber),
      'discNumber': serializer.toJson<int?>(discNumber),
      'durationMs': serializer.toJson<int>(durationMs),
      'bitrate': serializer.toJson<int?>(bitrate),
      'sampleRate': serializer.toJson<int?>(sampleRate),
      'format': serializer.toJson<String?>(format),
      'fileSize': serializer.toJson<int>(fileSize),
      'artworkPath': serializer.toJson<String?>(artworkPath),
      'source': serializer.toJson<String>(source),
      'externalId': serializer.toJson<String?>(externalId),
      'replayGainTrackDb': serializer.toJson<double?>(replayGainTrackDb),
      'replayGainAlbumDb': serializer.toJson<double?>(replayGainAlbumDb),
      'isFavorite': serializer.toJson<bool>(isFavorite),
      'playCount': serializer.toJson<int>(playCount),
      'skipCount': serializer.toJson<int>(skipCount),
      'lastPlayedAt': serializer.toJson<DateTime?>(lastPlayedAt),
      'addedAt': serializer.toJson<DateTime>(addedAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  TrackRow copyWith({
    int? id,
    String? path,
    String? title,
    String? artist,
    String? album,
    Value<String?> albumArtist = const Value.absent(),
    Value<String?> genre = const Value.absent(),
    Value<int?> year = const Value.absent(),
    Value<int?> trackNumber = const Value.absent(),
    Value<int?> discNumber = const Value.absent(),
    int? durationMs,
    Value<int?> bitrate = const Value.absent(),
    Value<int?> sampleRate = const Value.absent(),
    Value<String?> format = const Value.absent(),
    int? fileSize,
    Value<String?> artworkPath = const Value.absent(),
    String? source,
    Value<String?> externalId = const Value.absent(),
    Value<double?> replayGainTrackDb = const Value.absent(),
    Value<double?> replayGainAlbumDb = const Value.absent(),
    bool? isFavorite,
    int? playCount,
    int? skipCount,
    Value<DateTime?> lastPlayedAt = const Value.absent(),
    DateTime? addedAt,
    DateTime? updatedAt,
  }) => TrackRow(
    id: id ?? this.id,
    path: path ?? this.path,
    title: title ?? this.title,
    artist: artist ?? this.artist,
    album: album ?? this.album,
    albumArtist: albumArtist.present ? albumArtist.value : this.albumArtist,
    genre: genre.present ? genre.value : this.genre,
    year: year.present ? year.value : this.year,
    trackNumber: trackNumber.present ? trackNumber.value : this.trackNumber,
    discNumber: discNumber.present ? discNumber.value : this.discNumber,
    durationMs: durationMs ?? this.durationMs,
    bitrate: bitrate.present ? bitrate.value : this.bitrate,
    sampleRate: sampleRate.present ? sampleRate.value : this.sampleRate,
    format: format.present ? format.value : this.format,
    fileSize: fileSize ?? this.fileSize,
    artworkPath: artworkPath.present ? artworkPath.value : this.artworkPath,
    source: source ?? this.source,
    externalId: externalId.present ? externalId.value : this.externalId,
    replayGainTrackDb: replayGainTrackDb.present
        ? replayGainTrackDb.value
        : this.replayGainTrackDb,
    replayGainAlbumDb: replayGainAlbumDb.present
        ? replayGainAlbumDb.value
        : this.replayGainAlbumDb,
    isFavorite: isFavorite ?? this.isFavorite,
    playCount: playCount ?? this.playCount,
    skipCount: skipCount ?? this.skipCount,
    lastPlayedAt: lastPlayedAt.present ? lastPlayedAt.value : this.lastPlayedAt,
    addedAt: addedAt ?? this.addedAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  TrackRow copyWithCompanion(TracksCompanion data) {
    return TrackRow(
      id: data.id.present ? data.id.value : this.id,
      path: data.path.present ? data.path.value : this.path,
      title: data.title.present ? data.title.value : this.title,
      artist: data.artist.present ? data.artist.value : this.artist,
      album: data.album.present ? data.album.value : this.album,
      albumArtist: data.albumArtist.present
          ? data.albumArtist.value
          : this.albumArtist,
      genre: data.genre.present ? data.genre.value : this.genre,
      year: data.year.present ? data.year.value : this.year,
      trackNumber: data.trackNumber.present
          ? data.trackNumber.value
          : this.trackNumber,
      discNumber: data.discNumber.present
          ? data.discNumber.value
          : this.discNumber,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      bitrate: data.bitrate.present ? data.bitrate.value : this.bitrate,
      sampleRate: data.sampleRate.present
          ? data.sampleRate.value
          : this.sampleRate,
      format: data.format.present ? data.format.value : this.format,
      fileSize: data.fileSize.present ? data.fileSize.value : this.fileSize,
      artworkPath: data.artworkPath.present
          ? data.artworkPath.value
          : this.artworkPath,
      source: data.source.present ? data.source.value : this.source,
      externalId: data.externalId.present
          ? data.externalId.value
          : this.externalId,
      replayGainTrackDb: data.replayGainTrackDb.present
          ? data.replayGainTrackDb.value
          : this.replayGainTrackDb,
      replayGainAlbumDb: data.replayGainAlbumDb.present
          ? data.replayGainAlbumDb.value
          : this.replayGainAlbumDb,
      isFavorite: data.isFavorite.present
          ? data.isFavorite.value
          : this.isFavorite,
      playCount: data.playCount.present ? data.playCount.value : this.playCount,
      skipCount: data.skipCount.present ? data.skipCount.value : this.skipCount,
      lastPlayedAt: data.lastPlayedAt.present
          ? data.lastPlayedAt.value
          : this.lastPlayedAt,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TrackRow(')
          ..write('id: $id, ')
          ..write('path: $path, ')
          ..write('title: $title, ')
          ..write('artist: $artist, ')
          ..write('album: $album, ')
          ..write('albumArtist: $albumArtist, ')
          ..write('genre: $genre, ')
          ..write('year: $year, ')
          ..write('trackNumber: $trackNumber, ')
          ..write('discNumber: $discNumber, ')
          ..write('durationMs: $durationMs, ')
          ..write('bitrate: $bitrate, ')
          ..write('sampleRate: $sampleRate, ')
          ..write('format: $format, ')
          ..write('fileSize: $fileSize, ')
          ..write('artworkPath: $artworkPath, ')
          ..write('source: $source, ')
          ..write('externalId: $externalId, ')
          ..write('replayGainTrackDb: $replayGainTrackDb, ')
          ..write('replayGainAlbumDb: $replayGainAlbumDb, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('playCount: $playCount, ')
          ..write('skipCount: $skipCount, ')
          ..write('lastPlayedAt: $lastPlayedAt, ')
          ..write('addedAt: $addedAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    path,
    title,
    artist,
    album,
    albumArtist,
    genre,
    year,
    trackNumber,
    discNumber,
    durationMs,
    bitrate,
    sampleRate,
    format,
    fileSize,
    artworkPath,
    source,
    externalId,
    replayGainTrackDb,
    replayGainAlbumDb,
    isFavorite,
    playCount,
    skipCount,
    lastPlayedAt,
    addedAt,
    updatedAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TrackRow &&
          other.id == this.id &&
          other.path == this.path &&
          other.title == this.title &&
          other.artist == this.artist &&
          other.album == this.album &&
          other.albumArtist == this.albumArtist &&
          other.genre == this.genre &&
          other.year == this.year &&
          other.trackNumber == this.trackNumber &&
          other.discNumber == this.discNumber &&
          other.durationMs == this.durationMs &&
          other.bitrate == this.bitrate &&
          other.sampleRate == this.sampleRate &&
          other.format == this.format &&
          other.fileSize == this.fileSize &&
          other.artworkPath == this.artworkPath &&
          other.source == this.source &&
          other.externalId == this.externalId &&
          other.replayGainTrackDb == this.replayGainTrackDb &&
          other.replayGainAlbumDb == this.replayGainAlbumDb &&
          other.isFavorite == this.isFavorite &&
          other.playCount == this.playCount &&
          other.skipCount == this.skipCount &&
          other.lastPlayedAt == this.lastPlayedAt &&
          other.addedAt == this.addedAt &&
          other.updatedAt == this.updatedAt);
}

class TracksCompanion extends UpdateCompanion<TrackRow> {
  final Value<int> id;
  final Value<String> path;
  final Value<String> title;
  final Value<String> artist;
  final Value<String> album;
  final Value<String?> albumArtist;
  final Value<String?> genre;
  final Value<int?> year;
  final Value<int?> trackNumber;
  final Value<int?> discNumber;
  final Value<int> durationMs;
  final Value<int?> bitrate;
  final Value<int?> sampleRate;
  final Value<String?> format;
  final Value<int> fileSize;
  final Value<String?> artworkPath;
  final Value<String> source;
  final Value<String?> externalId;
  final Value<double?> replayGainTrackDb;
  final Value<double?> replayGainAlbumDb;
  final Value<bool> isFavorite;
  final Value<int> playCount;
  final Value<int> skipCount;
  final Value<DateTime?> lastPlayedAt;
  final Value<DateTime> addedAt;
  final Value<DateTime> updatedAt;
  const TracksCompanion({
    this.id = const Value.absent(),
    this.path = const Value.absent(),
    this.title = const Value.absent(),
    this.artist = const Value.absent(),
    this.album = const Value.absent(),
    this.albumArtist = const Value.absent(),
    this.genre = const Value.absent(),
    this.year = const Value.absent(),
    this.trackNumber = const Value.absent(),
    this.discNumber = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.bitrate = const Value.absent(),
    this.sampleRate = const Value.absent(),
    this.format = const Value.absent(),
    this.fileSize = const Value.absent(),
    this.artworkPath = const Value.absent(),
    this.source = const Value.absent(),
    this.externalId = const Value.absent(),
    this.replayGainTrackDb = const Value.absent(),
    this.replayGainAlbumDb = const Value.absent(),
    this.isFavorite = const Value.absent(),
    this.playCount = const Value.absent(),
    this.skipCount = const Value.absent(),
    this.lastPlayedAt = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  TracksCompanion.insert({
    this.id = const Value.absent(),
    required String path,
    required String title,
    this.artist = const Value.absent(),
    this.album = const Value.absent(),
    this.albumArtist = const Value.absent(),
    this.genre = const Value.absent(),
    this.year = const Value.absent(),
    this.trackNumber = const Value.absent(),
    this.discNumber = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.bitrate = const Value.absent(),
    this.sampleRate = const Value.absent(),
    this.format = const Value.absent(),
    this.fileSize = const Value.absent(),
    this.artworkPath = const Value.absent(),
    this.source = const Value.absent(),
    this.externalId = const Value.absent(),
    this.replayGainTrackDb = const Value.absent(),
    this.replayGainAlbumDb = const Value.absent(),
    this.isFavorite = const Value.absent(),
    this.playCount = const Value.absent(),
    this.skipCount = const Value.absent(),
    this.lastPlayedAt = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : path = Value(path),
       title = Value(title);
  static Insertable<TrackRow> custom({
    Expression<int>? id,
    Expression<String>? path,
    Expression<String>? title,
    Expression<String>? artist,
    Expression<String>? album,
    Expression<String>? albumArtist,
    Expression<String>? genre,
    Expression<int>? year,
    Expression<int>? trackNumber,
    Expression<int>? discNumber,
    Expression<int>? durationMs,
    Expression<int>? bitrate,
    Expression<int>? sampleRate,
    Expression<String>? format,
    Expression<int>? fileSize,
    Expression<String>? artworkPath,
    Expression<String>? source,
    Expression<String>? externalId,
    Expression<double>? replayGainTrackDb,
    Expression<double>? replayGainAlbumDb,
    Expression<bool>? isFavorite,
    Expression<int>? playCount,
    Expression<int>? skipCount,
    Expression<DateTime>? lastPlayedAt,
    Expression<DateTime>? addedAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (path != null) 'path': path,
      if (title != null) 'title': title,
      if (artist != null) 'artist': artist,
      if (album != null) 'album': album,
      if (albumArtist != null) 'album_artist': albumArtist,
      if (genre != null) 'genre': genre,
      if (year != null) 'year': year,
      if (trackNumber != null) 'track_number': trackNumber,
      if (discNumber != null) 'disc_number': discNumber,
      if (durationMs != null) 'duration_ms': durationMs,
      if (bitrate != null) 'bitrate': bitrate,
      if (sampleRate != null) 'sample_rate': sampleRate,
      if (format != null) 'format': format,
      if (fileSize != null) 'file_size': fileSize,
      if (artworkPath != null) 'artwork_path': artworkPath,
      if (source != null) 'source': source,
      if (externalId != null) 'external_id': externalId,
      if (replayGainTrackDb != null) 'replay_gain_track_db': replayGainTrackDb,
      if (replayGainAlbumDb != null) 'replay_gain_album_db': replayGainAlbumDb,
      if (isFavorite != null) 'is_favorite': isFavorite,
      if (playCount != null) 'play_count': playCount,
      if (skipCount != null) 'skip_count': skipCount,
      if (lastPlayedAt != null) 'last_played_at': lastPlayedAt,
      if (addedAt != null) 'added_at': addedAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  TracksCompanion copyWith({
    Value<int>? id,
    Value<String>? path,
    Value<String>? title,
    Value<String>? artist,
    Value<String>? album,
    Value<String?>? albumArtist,
    Value<String?>? genre,
    Value<int?>? year,
    Value<int?>? trackNumber,
    Value<int?>? discNumber,
    Value<int>? durationMs,
    Value<int?>? bitrate,
    Value<int?>? sampleRate,
    Value<String?>? format,
    Value<int>? fileSize,
    Value<String?>? artworkPath,
    Value<String>? source,
    Value<String?>? externalId,
    Value<double?>? replayGainTrackDb,
    Value<double?>? replayGainAlbumDb,
    Value<bool>? isFavorite,
    Value<int>? playCount,
    Value<int>? skipCount,
    Value<DateTime?>? lastPlayedAt,
    Value<DateTime>? addedAt,
    Value<DateTime>? updatedAt,
  }) {
    return TracksCompanion(
      id: id ?? this.id,
      path: path ?? this.path,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      albumArtist: albumArtist ?? this.albumArtist,
      genre: genre ?? this.genre,
      year: year ?? this.year,
      trackNumber: trackNumber ?? this.trackNumber,
      discNumber: discNumber ?? this.discNumber,
      durationMs: durationMs ?? this.durationMs,
      bitrate: bitrate ?? this.bitrate,
      sampleRate: sampleRate ?? this.sampleRate,
      format: format ?? this.format,
      fileSize: fileSize ?? this.fileSize,
      artworkPath: artworkPath ?? this.artworkPath,
      source: source ?? this.source,
      externalId: externalId ?? this.externalId,
      replayGainTrackDb: replayGainTrackDb ?? this.replayGainTrackDb,
      replayGainAlbumDb: replayGainAlbumDb ?? this.replayGainAlbumDb,
      isFavorite: isFavorite ?? this.isFavorite,
      playCount: playCount ?? this.playCount,
      skipCount: skipCount ?? this.skipCount,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
      addedAt: addedAt ?? this.addedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (artist.present) {
      map['artist'] = Variable<String>(artist.value);
    }
    if (album.present) {
      map['album'] = Variable<String>(album.value);
    }
    if (albumArtist.present) {
      map['album_artist'] = Variable<String>(albumArtist.value);
    }
    if (genre.present) {
      map['genre'] = Variable<String>(genre.value);
    }
    if (year.present) {
      map['year'] = Variable<int>(year.value);
    }
    if (trackNumber.present) {
      map['track_number'] = Variable<int>(trackNumber.value);
    }
    if (discNumber.present) {
      map['disc_number'] = Variable<int>(discNumber.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (bitrate.present) {
      map['bitrate'] = Variable<int>(bitrate.value);
    }
    if (sampleRate.present) {
      map['sample_rate'] = Variable<int>(sampleRate.value);
    }
    if (format.present) {
      map['format'] = Variable<String>(format.value);
    }
    if (fileSize.present) {
      map['file_size'] = Variable<int>(fileSize.value);
    }
    if (artworkPath.present) {
      map['artwork_path'] = Variable<String>(artworkPath.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (externalId.present) {
      map['external_id'] = Variable<String>(externalId.value);
    }
    if (replayGainTrackDb.present) {
      map['replay_gain_track_db'] = Variable<double>(replayGainTrackDb.value);
    }
    if (replayGainAlbumDb.present) {
      map['replay_gain_album_db'] = Variable<double>(replayGainAlbumDb.value);
    }
    if (isFavorite.present) {
      map['is_favorite'] = Variable<bool>(isFavorite.value);
    }
    if (playCount.present) {
      map['play_count'] = Variable<int>(playCount.value);
    }
    if (skipCount.present) {
      map['skip_count'] = Variable<int>(skipCount.value);
    }
    if (lastPlayedAt.present) {
      map['last_played_at'] = Variable<DateTime>(lastPlayedAt.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TracksCompanion(')
          ..write('id: $id, ')
          ..write('path: $path, ')
          ..write('title: $title, ')
          ..write('artist: $artist, ')
          ..write('album: $album, ')
          ..write('albumArtist: $albumArtist, ')
          ..write('genre: $genre, ')
          ..write('year: $year, ')
          ..write('trackNumber: $trackNumber, ')
          ..write('discNumber: $discNumber, ')
          ..write('durationMs: $durationMs, ')
          ..write('bitrate: $bitrate, ')
          ..write('sampleRate: $sampleRate, ')
          ..write('format: $format, ')
          ..write('fileSize: $fileSize, ')
          ..write('artworkPath: $artworkPath, ')
          ..write('source: $source, ')
          ..write('externalId: $externalId, ')
          ..write('replayGainTrackDb: $replayGainTrackDb, ')
          ..write('replayGainAlbumDb: $replayGainAlbumDb, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('playCount: $playCount, ')
          ..write('skipCount: $skipCount, ')
          ..write('lastPlayedAt: $lastPlayedAt, ')
          ..write('addedAt: $addedAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $ScanFoldersTable extends ScanFolders
    with TableInfo<$ScanFoldersTable, ScanFolderRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ScanFoldersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _recursiveMeta = const VerificationMeta(
    'recursive',
  );
  @override
  late final GeneratedColumn<bool> recursive = GeneratedColumn<bool>(
    'recursive',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("recursive" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<DateTime> addedAt = GeneratedColumn<DateTime>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _lastScanAtMeta = const VerificationMeta(
    'lastScanAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastScanAt = GeneratedColumn<DateTime>(
    'last_scan_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    path,
    recursive,
    addedAt,
    lastScanAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'scan_folders';
  @override
  VerificationContext validateIntegrity(
    Insertable<ScanFolderRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('recursive')) {
      context.handle(
        _recursiveMeta,
        recursive.isAcceptableOrUnknown(data['recursive']!, _recursiveMeta),
      );
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    }
    if (data.containsKey('last_scan_at')) {
      context.handle(
        _lastScanAtMeta,
        lastScanAt.isAcceptableOrUnknown(
          data['last_scan_at']!,
          _lastScanAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ScanFolderRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ScanFolderRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      recursive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}recursive'],
      )!,
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}added_at'],
      )!,
      lastScanAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_scan_at'],
      ),
    );
  }

  @override
  $ScanFoldersTable createAlias(String alias) {
    return $ScanFoldersTable(attachedDatabase, alias);
  }
}

class ScanFolderRow extends DataClass implements Insertable<ScanFolderRow> {
  final int id;
  final String path;
  final bool recursive;
  final DateTime addedAt;
  final DateTime? lastScanAt;
  const ScanFolderRow({
    required this.id,
    required this.path,
    required this.recursive,
    required this.addedAt,
    this.lastScanAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['path'] = Variable<String>(path);
    map['recursive'] = Variable<bool>(recursive);
    map['added_at'] = Variable<DateTime>(addedAt);
    if (!nullToAbsent || lastScanAt != null) {
      map['last_scan_at'] = Variable<DateTime>(lastScanAt);
    }
    return map;
  }

  ScanFoldersCompanion toCompanion(bool nullToAbsent) {
    return ScanFoldersCompanion(
      id: Value(id),
      path: Value(path),
      recursive: Value(recursive),
      addedAt: Value(addedAt),
      lastScanAt: lastScanAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastScanAt),
    );
  }

  factory ScanFolderRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ScanFolderRow(
      id: serializer.fromJson<int>(json['id']),
      path: serializer.fromJson<String>(json['path']),
      recursive: serializer.fromJson<bool>(json['recursive']),
      addedAt: serializer.fromJson<DateTime>(json['addedAt']),
      lastScanAt: serializer.fromJson<DateTime?>(json['lastScanAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'path': serializer.toJson<String>(path),
      'recursive': serializer.toJson<bool>(recursive),
      'addedAt': serializer.toJson<DateTime>(addedAt),
      'lastScanAt': serializer.toJson<DateTime?>(lastScanAt),
    };
  }

  ScanFolderRow copyWith({
    int? id,
    String? path,
    bool? recursive,
    DateTime? addedAt,
    Value<DateTime?> lastScanAt = const Value.absent(),
  }) => ScanFolderRow(
    id: id ?? this.id,
    path: path ?? this.path,
    recursive: recursive ?? this.recursive,
    addedAt: addedAt ?? this.addedAt,
    lastScanAt: lastScanAt.present ? lastScanAt.value : this.lastScanAt,
  );
  ScanFolderRow copyWithCompanion(ScanFoldersCompanion data) {
    return ScanFolderRow(
      id: data.id.present ? data.id.value : this.id,
      path: data.path.present ? data.path.value : this.path,
      recursive: data.recursive.present ? data.recursive.value : this.recursive,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
      lastScanAt: data.lastScanAt.present
          ? data.lastScanAt.value
          : this.lastScanAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ScanFolderRow(')
          ..write('id: $id, ')
          ..write('path: $path, ')
          ..write('recursive: $recursive, ')
          ..write('addedAt: $addedAt, ')
          ..write('lastScanAt: $lastScanAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, path, recursive, addedAt, lastScanAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ScanFolderRow &&
          other.id == this.id &&
          other.path == this.path &&
          other.recursive == this.recursive &&
          other.addedAt == this.addedAt &&
          other.lastScanAt == this.lastScanAt);
}

class ScanFoldersCompanion extends UpdateCompanion<ScanFolderRow> {
  final Value<int> id;
  final Value<String> path;
  final Value<bool> recursive;
  final Value<DateTime> addedAt;
  final Value<DateTime?> lastScanAt;
  const ScanFoldersCompanion({
    this.id = const Value.absent(),
    this.path = const Value.absent(),
    this.recursive = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.lastScanAt = const Value.absent(),
  });
  ScanFoldersCompanion.insert({
    this.id = const Value.absent(),
    required String path,
    this.recursive = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.lastScanAt = const Value.absent(),
  }) : path = Value(path);
  static Insertable<ScanFolderRow> custom({
    Expression<int>? id,
    Expression<String>? path,
    Expression<bool>? recursive,
    Expression<DateTime>? addedAt,
    Expression<DateTime>? lastScanAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (path != null) 'path': path,
      if (recursive != null) 'recursive': recursive,
      if (addedAt != null) 'added_at': addedAt,
      if (lastScanAt != null) 'last_scan_at': lastScanAt,
    });
  }

  ScanFoldersCompanion copyWith({
    Value<int>? id,
    Value<String>? path,
    Value<bool>? recursive,
    Value<DateTime>? addedAt,
    Value<DateTime?>? lastScanAt,
  }) {
    return ScanFoldersCompanion(
      id: id ?? this.id,
      path: path ?? this.path,
      recursive: recursive ?? this.recursive,
      addedAt: addedAt ?? this.addedAt,
      lastScanAt: lastScanAt ?? this.lastScanAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (recursive.present) {
      map['recursive'] = Variable<bool>(recursive.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
    }
    if (lastScanAt.present) {
      map['last_scan_at'] = Variable<DateTime>(lastScanAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ScanFoldersCompanion(')
          ..write('id: $id, ')
          ..write('path: $path, ')
          ..write('recursive: $recursive, ')
          ..write('addedAt: $addedAt, ')
          ..write('lastScanAt: $lastScanAt')
          ..write(')'))
        .toString();
  }
}

class $PlaylistsTable extends Playlists
    with TableInfo<$PlaylistsTable, PlaylistRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlaylistsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isSmartMeta = const VerificationMeta(
    'isSmart',
  );
  @override
  late final GeneratedColumn<bool> isSmart = GeneratedColumn<bool>(
    'is_smart',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_smart" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    description,
    isSmart,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'playlists';
  @override
  VerificationContext validateIntegrity(
    Insertable<PlaylistRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('is_smart')) {
      context.handle(
        _isSmartMeta,
        isSmart.isAcceptableOrUnknown(data['is_smart']!, _isSmartMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PlaylistRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlaylistRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      isSmart: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_smart'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $PlaylistsTable createAlias(String alias) {
    return $PlaylistsTable(attachedDatabase, alias);
  }
}

class PlaylistRow extends DataClass implements Insertable<PlaylistRow> {
  final int id;
  final String name;
  final String? description;
  final bool isSmart;
  final DateTime createdAt;
  final DateTime updatedAt;
  const PlaylistRow({
    required this.id,
    required this.name,
    this.description,
    required this.isSmart,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['is_smart'] = Variable<bool>(isSmart);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  PlaylistsCompanion toCompanion(bool nullToAbsent) {
    return PlaylistsCompanion(
      id: Value(id),
      name: Value(name),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      isSmart: Value(isSmart),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory PlaylistRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlaylistRow(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      description: serializer.fromJson<String?>(json['description']),
      isSmart: serializer.fromJson<bool>(json['isSmart']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'description': serializer.toJson<String?>(description),
      'isSmart': serializer.toJson<bool>(isSmart),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  PlaylistRow copyWith({
    int? id,
    String? name,
    Value<String?> description = const Value.absent(),
    bool? isSmart,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => PlaylistRow(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description.present ? description.value : this.description,
    isSmart: isSmart ?? this.isSmart,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  PlaylistRow copyWithCompanion(PlaylistsCompanion data) {
    return PlaylistRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      description: data.description.present
          ? data.description.value
          : this.description,
      isSmart: data.isSmart.present ? data.isSmart.value : this.isSmart,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlaylistRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('isSmart: $isSmart, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, description, isSmart, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlaylistRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.description == this.description &&
          other.isSmart == this.isSmart &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class PlaylistsCompanion extends UpdateCompanion<PlaylistRow> {
  final Value<int> id;
  final Value<String> name;
  final Value<String?> description;
  final Value<bool> isSmart;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const PlaylistsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.isSmart = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  PlaylistsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.description = const Value.absent(),
    this.isSmart = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : name = Value(name);
  static Insertable<PlaylistRow> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? description,
    Expression<bool>? isSmart,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (isSmart != null) 'is_smart': isSmart,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  PlaylistsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String?>? description,
    Value<bool>? isSmart,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return PlaylistsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      isSmart: isSmart ?? this.isSmart,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (isSmart.present) {
      map['is_smart'] = Variable<bool>(isSmart.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlaylistsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('isSmart: $isSmart, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $PlaylistEntriesTable extends PlaylistEntries
    with TableInfo<$PlaylistEntriesTable, PlaylistEntryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlaylistEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _playlistIdMeta = const VerificationMeta(
    'playlistId',
  );
  @override
  late final GeneratedColumn<int> playlistId = GeneratedColumn<int>(
    'playlist_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES playlists (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _trackIdMeta = const VerificationMeta(
    'trackId',
  );
  @override
  late final GeneratedColumn<int> trackId = GeneratedColumn<int>(
    'track_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES tracks (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [id, playlistId, trackId, position];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'playlist_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<PlaylistEntryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('playlist_id')) {
      context.handle(
        _playlistIdMeta,
        playlistId.isAcceptableOrUnknown(data['playlist_id']!, _playlistIdMeta),
      );
    } else if (isInserting) {
      context.missing(_playlistIdMeta);
    }
    if (data.containsKey('track_id')) {
      context.handle(
        _trackIdMeta,
        trackId.isAcceptableOrUnknown(data['track_id']!, _trackIdMeta),
      );
    } else if (isInserting) {
      context.missing(_trackIdMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PlaylistEntryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlaylistEntryRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      playlistId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}playlist_id'],
      )!,
      trackId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}track_id'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
    );
  }

  @override
  $PlaylistEntriesTable createAlias(String alias) {
    return $PlaylistEntriesTable(attachedDatabase, alias);
  }
}

class PlaylistEntryRow extends DataClass
    implements Insertable<PlaylistEntryRow> {
  final int id;
  final int playlistId;
  final int trackId;
  final int position;
  const PlaylistEntryRow({
    required this.id,
    required this.playlistId,
    required this.trackId,
    required this.position,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['playlist_id'] = Variable<int>(playlistId);
    map['track_id'] = Variable<int>(trackId);
    map['position'] = Variable<int>(position);
    return map;
  }

  PlaylistEntriesCompanion toCompanion(bool nullToAbsent) {
    return PlaylistEntriesCompanion(
      id: Value(id),
      playlistId: Value(playlistId),
      trackId: Value(trackId),
      position: Value(position),
    );
  }

  factory PlaylistEntryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlaylistEntryRow(
      id: serializer.fromJson<int>(json['id']),
      playlistId: serializer.fromJson<int>(json['playlistId']),
      trackId: serializer.fromJson<int>(json['trackId']),
      position: serializer.fromJson<int>(json['position']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'playlistId': serializer.toJson<int>(playlistId),
      'trackId': serializer.toJson<int>(trackId),
      'position': serializer.toJson<int>(position),
    };
  }

  PlaylistEntryRow copyWith({
    int? id,
    int? playlistId,
    int? trackId,
    int? position,
  }) => PlaylistEntryRow(
    id: id ?? this.id,
    playlistId: playlistId ?? this.playlistId,
    trackId: trackId ?? this.trackId,
    position: position ?? this.position,
  );
  PlaylistEntryRow copyWithCompanion(PlaylistEntriesCompanion data) {
    return PlaylistEntryRow(
      id: data.id.present ? data.id.value : this.id,
      playlistId: data.playlistId.present
          ? data.playlistId.value
          : this.playlistId,
      trackId: data.trackId.present ? data.trackId.value : this.trackId,
      position: data.position.present ? data.position.value : this.position,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlaylistEntryRow(')
          ..write('id: $id, ')
          ..write('playlistId: $playlistId, ')
          ..write('trackId: $trackId, ')
          ..write('position: $position')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, playlistId, trackId, position);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlaylistEntryRow &&
          other.id == this.id &&
          other.playlistId == this.playlistId &&
          other.trackId == this.trackId &&
          other.position == this.position);
}

class PlaylistEntriesCompanion extends UpdateCompanion<PlaylistEntryRow> {
  final Value<int> id;
  final Value<int> playlistId;
  final Value<int> trackId;
  final Value<int> position;
  const PlaylistEntriesCompanion({
    this.id = const Value.absent(),
    this.playlistId = const Value.absent(),
    this.trackId = const Value.absent(),
    this.position = const Value.absent(),
  });
  PlaylistEntriesCompanion.insert({
    this.id = const Value.absent(),
    required int playlistId,
    required int trackId,
    this.position = const Value.absent(),
  }) : playlistId = Value(playlistId),
       trackId = Value(trackId);
  static Insertable<PlaylistEntryRow> custom({
    Expression<int>? id,
    Expression<int>? playlistId,
    Expression<int>? trackId,
    Expression<int>? position,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (playlistId != null) 'playlist_id': playlistId,
      if (trackId != null) 'track_id': trackId,
      if (position != null) 'position': position,
    });
  }

  PlaylistEntriesCompanion copyWith({
    Value<int>? id,
    Value<int>? playlistId,
    Value<int>? trackId,
    Value<int>? position,
  }) {
    return PlaylistEntriesCompanion(
      id: id ?? this.id,
      playlistId: playlistId ?? this.playlistId,
      trackId: trackId ?? this.trackId,
      position: position ?? this.position,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (playlistId.present) {
      map['playlist_id'] = Variable<int>(playlistId.value);
    }
    if (trackId.present) {
      map['track_id'] = Variable<int>(trackId.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlaylistEntriesCompanion(')
          ..write('id: $id, ')
          ..write('playlistId: $playlistId, ')
          ..write('trackId: $trackId, ')
          ..write('position: $position')
          ..write(')'))
        .toString();
  }
}

class $PlayHistoryTable extends PlayHistory
    with TableInfo<$PlayHistoryTable, PlayHistoryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlayHistoryTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _trackIdMeta = const VerificationMeta(
    'trackId',
  );
  @override
  late final GeneratedColumn<int> trackId = GeneratedColumn<int>(
    'track_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES tracks (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _msPlayedMeta = const VerificationMeta(
    'msPlayed',
  );
  @override
  late final GeneratedColumn<int> msPlayed = GeneratedColumn<int>(
    'ms_played',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _completedMeta = const VerificationMeta(
    'completed',
  );
  @override
  late final GeneratedColumn<bool> completed = GeneratedColumn<bool>(
    'completed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("completed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    trackId,
    startedAt,
    msPlayed,
    completed,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'play_history';
  @override
  VerificationContext validateIntegrity(
    Insertable<PlayHistoryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('track_id')) {
      context.handle(
        _trackIdMeta,
        trackId.isAcceptableOrUnknown(data['track_id']!, _trackIdMeta),
      );
    } else if (isInserting) {
      context.missing(_trackIdMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    }
    if (data.containsKey('ms_played')) {
      context.handle(
        _msPlayedMeta,
        msPlayed.isAcceptableOrUnknown(data['ms_played']!, _msPlayedMeta),
      );
    }
    if (data.containsKey('completed')) {
      context.handle(
        _completedMeta,
        completed.isAcceptableOrUnknown(data['completed']!, _completedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PlayHistoryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlayHistoryRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      trackId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}track_id'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      )!,
      msPlayed: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ms_played'],
      )!,
      completed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}completed'],
      )!,
    );
  }

  @override
  $PlayHistoryTable createAlias(String alias) {
    return $PlayHistoryTable(attachedDatabase, alias);
  }
}

class PlayHistoryRow extends DataClass implements Insertable<PlayHistoryRow> {
  final int id;
  final int trackId;
  final DateTime startedAt;
  final int msPlayed;
  final bool completed;
  const PlayHistoryRow({
    required this.id,
    required this.trackId,
    required this.startedAt,
    required this.msPlayed,
    required this.completed,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['track_id'] = Variable<int>(trackId);
    map['started_at'] = Variable<DateTime>(startedAt);
    map['ms_played'] = Variable<int>(msPlayed);
    map['completed'] = Variable<bool>(completed);
    return map;
  }

  PlayHistoryCompanion toCompanion(bool nullToAbsent) {
    return PlayHistoryCompanion(
      id: Value(id),
      trackId: Value(trackId),
      startedAt: Value(startedAt),
      msPlayed: Value(msPlayed),
      completed: Value(completed),
    );
  }

  factory PlayHistoryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlayHistoryRow(
      id: serializer.fromJson<int>(json['id']),
      trackId: serializer.fromJson<int>(json['trackId']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      msPlayed: serializer.fromJson<int>(json['msPlayed']),
      completed: serializer.fromJson<bool>(json['completed']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'trackId': serializer.toJson<int>(trackId),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'msPlayed': serializer.toJson<int>(msPlayed),
      'completed': serializer.toJson<bool>(completed),
    };
  }

  PlayHistoryRow copyWith({
    int? id,
    int? trackId,
    DateTime? startedAt,
    int? msPlayed,
    bool? completed,
  }) => PlayHistoryRow(
    id: id ?? this.id,
    trackId: trackId ?? this.trackId,
    startedAt: startedAt ?? this.startedAt,
    msPlayed: msPlayed ?? this.msPlayed,
    completed: completed ?? this.completed,
  );
  PlayHistoryRow copyWithCompanion(PlayHistoryCompanion data) {
    return PlayHistoryRow(
      id: data.id.present ? data.id.value : this.id,
      trackId: data.trackId.present ? data.trackId.value : this.trackId,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      msPlayed: data.msPlayed.present ? data.msPlayed.value : this.msPlayed,
      completed: data.completed.present ? data.completed.value : this.completed,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlayHistoryRow(')
          ..write('id: $id, ')
          ..write('trackId: $trackId, ')
          ..write('startedAt: $startedAt, ')
          ..write('msPlayed: $msPlayed, ')
          ..write('completed: $completed')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, trackId, startedAt, msPlayed, completed);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlayHistoryRow &&
          other.id == this.id &&
          other.trackId == this.trackId &&
          other.startedAt == this.startedAt &&
          other.msPlayed == this.msPlayed &&
          other.completed == this.completed);
}

class PlayHistoryCompanion extends UpdateCompanion<PlayHistoryRow> {
  final Value<int> id;
  final Value<int> trackId;
  final Value<DateTime> startedAt;
  final Value<int> msPlayed;
  final Value<bool> completed;
  const PlayHistoryCompanion({
    this.id = const Value.absent(),
    this.trackId = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.msPlayed = const Value.absent(),
    this.completed = const Value.absent(),
  });
  PlayHistoryCompanion.insert({
    this.id = const Value.absent(),
    required int trackId,
    this.startedAt = const Value.absent(),
    this.msPlayed = const Value.absent(),
    this.completed = const Value.absent(),
  }) : trackId = Value(trackId);
  static Insertable<PlayHistoryRow> custom({
    Expression<int>? id,
    Expression<int>? trackId,
    Expression<DateTime>? startedAt,
    Expression<int>? msPlayed,
    Expression<bool>? completed,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (trackId != null) 'track_id': trackId,
      if (startedAt != null) 'started_at': startedAt,
      if (msPlayed != null) 'ms_played': msPlayed,
      if (completed != null) 'completed': completed,
    });
  }

  PlayHistoryCompanion copyWith({
    Value<int>? id,
    Value<int>? trackId,
    Value<DateTime>? startedAt,
    Value<int>? msPlayed,
    Value<bool>? completed,
  }) {
    return PlayHistoryCompanion(
      id: id ?? this.id,
      trackId: trackId ?? this.trackId,
      startedAt: startedAt ?? this.startedAt,
      msPlayed: msPlayed ?? this.msPlayed,
      completed: completed ?? this.completed,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (trackId.present) {
      map['track_id'] = Variable<int>(trackId.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (msPlayed.present) {
      map['ms_played'] = Variable<int>(msPlayed.value);
    }
    if (completed.present) {
      map['completed'] = Variable<bool>(completed.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlayHistoryCompanion(')
          ..write('id: $id, ')
          ..write('trackId: $trackId, ')
          ..write('startedAt: $startedAt, ')
          ..write('msPlayed: $msPlayed, ')
          ..write('completed: $completed')
          ..write(')'))
        .toString();
  }
}

class $EqPresetsTable extends EqPresets
    with TableInfo<$EqPresetsTable, EqPresetRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EqPresetsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _isBuiltInMeta = const VerificationMeta(
    'isBuiltIn',
  );
  @override
  late final GeneratedColumn<bool> isBuiltIn = GeneratedColumn<bool>(
    'is_built_in',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_built_in" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _bandsJsonMeta = const VerificationMeta(
    'bandsJson',
  );
  @override
  late final GeneratedColumn<String> bandsJson = GeneratedColumn<String>(
    'bands_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _preampDbMeta = const VerificationMeta(
    'preampDb',
  );
  @override
  late final GeneratedColumn<double> preampDb = GeneratedColumn<double>(
    'preamp_db',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _configJsonMeta = const VerificationMeta(
    'configJson',
  );
  @override
  late final GeneratedColumn<String> configJson = GeneratedColumn<String>(
    'config_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    isBuiltIn,
    bandsJson,
    preampDb,
    configJson,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'eq_presets';
  @override
  VerificationContext validateIntegrity(
    Insertable<EqPresetRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('is_built_in')) {
      context.handle(
        _isBuiltInMeta,
        isBuiltIn.isAcceptableOrUnknown(data['is_built_in']!, _isBuiltInMeta),
      );
    }
    if (data.containsKey('bands_json')) {
      context.handle(
        _bandsJsonMeta,
        bandsJson.isAcceptableOrUnknown(data['bands_json']!, _bandsJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_bandsJsonMeta);
    }
    if (data.containsKey('preamp_db')) {
      context.handle(
        _preampDbMeta,
        preampDb.isAcceptableOrUnknown(data['preamp_db']!, _preampDbMeta),
      );
    }
    if (data.containsKey('config_json')) {
      context.handle(
        _configJsonMeta,
        configJson.isAcceptableOrUnknown(data['config_json']!, _configJsonMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  EqPresetRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EqPresetRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      isBuiltIn: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_built_in'],
      )!,
      bandsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bands_json'],
      )!,
      preampDb: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}preamp_db'],
      )!,
      configJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}config_json'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $EqPresetsTable createAlias(String alias) {
    return $EqPresetsTable(attachedDatabase, alias);
  }
}

class EqPresetRow extends DataClass implements Insertable<EqPresetRow> {
  final int id;
  final String name;
  final bool isBuiltIn;
  final String bandsJson;
  final double preampDb;
  final String? configJson;
  final DateTime createdAt;
  const EqPresetRow({
    required this.id,
    required this.name,
    required this.isBuiltIn,
    required this.bandsJson,
    required this.preampDb,
    this.configJson,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['is_built_in'] = Variable<bool>(isBuiltIn);
    map['bands_json'] = Variable<String>(bandsJson);
    map['preamp_db'] = Variable<double>(preampDb);
    if (!nullToAbsent || configJson != null) {
      map['config_json'] = Variable<String>(configJson);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  EqPresetsCompanion toCompanion(bool nullToAbsent) {
    return EqPresetsCompanion(
      id: Value(id),
      name: Value(name),
      isBuiltIn: Value(isBuiltIn),
      bandsJson: Value(bandsJson),
      preampDb: Value(preampDb),
      configJson: configJson == null && nullToAbsent
          ? const Value.absent()
          : Value(configJson),
      createdAt: Value(createdAt),
    );
  }

  factory EqPresetRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EqPresetRow(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      isBuiltIn: serializer.fromJson<bool>(json['isBuiltIn']),
      bandsJson: serializer.fromJson<String>(json['bandsJson']),
      preampDb: serializer.fromJson<double>(json['preampDb']),
      configJson: serializer.fromJson<String?>(json['configJson']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'isBuiltIn': serializer.toJson<bool>(isBuiltIn),
      'bandsJson': serializer.toJson<String>(bandsJson),
      'preampDb': serializer.toJson<double>(preampDb),
      'configJson': serializer.toJson<String?>(configJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  EqPresetRow copyWith({
    int? id,
    String? name,
    bool? isBuiltIn,
    String? bandsJson,
    double? preampDb,
    Value<String?> configJson = const Value.absent(),
    DateTime? createdAt,
  }) => EqPresetRow(
    id: id ?? this.id,
    name: name ?? this.name,
    isBuiltIn: isBuiltIn ?? this.isBuiltIn,
    bandsJson: bandsJson ?? this.bandsJson,
    preampDb: preampDb ?? this.preampDb,
    configJson: configJson.present ? configJson.value : this.configJson,
    createdAt: createdAt ?? this.createdAt,
  );
  EqPresetRow copyWithCompanion(EqPresetsCompanion data) {
    return EqPresetRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      isBuiltIn: data.isBuiltIn.present ? data.isBuiltIn.value : this.isBuiltIn,
      bandsJson: data.bandsJson.present ? data.bandsJson.value : this.bandsJson,
      preampDb: data.preampDb.present ? data.preampDb.value : this.preampDb,
      configJson: data.configJson.present
          ? data.configJson.value
          : this.configJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EqPresetRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('isBuiltIn: $isBuiltIn, ')
          ..write('bandsJson: $bandsJson, ')
          ..write('preampDb: $preampDb, ')
          ..write('configJson: $configJson, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    isBuiltIn,
    bandsJson,
    preampDb,
    configJson,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EqPresetRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.isBuiltIn == this.isBuiltIn &&
          other.bandsJson == this.bandsJson &&
          other.preampDb == this.preampDb &&
          other.configJson == this.configJson &&
          other.createdAt == this.createdAt);
}

class EqPresetsCompanion extends UpdateCompanion<EqPresetRow> {
  final Value<int> id;
  final Value<String> name;
  final Value<bool> isBuiltIn;
  final Value<String> bandsJson;
  final Value<double> preampDb;
  final Value<String?> configJson;
  final Value<DateTime> createdAt;
  const EqPresetsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.isBuiltIn = const Value.absent(),
    this.bandsJson = const Value.absent(),
    this.preampDb = const Value.absent(),
    this.configJson = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  EqPresetsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.isBuiltIn = const Value.absent(),
    required String bandsJson,
    this.preampDb = const Value.absent(),
    this.configJson = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : name = Value(name),
       bandsJson = Value(bandsJson);
  static Insertable<EqPresetRow> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<bool>? isBuiltIn,
    Expression<String>? bandsJson,
    Expression<double>? preampDb,
    Expression<String>? configJson,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (isBuiltIn != null) 'is_built_in': isBuiltIn,
      if (bandsJson != null) 'bands_json': bandsJson,
      if (preampDb != null) 'preamp_db': preampDb,
      if (configJson != null) 'config_json': configJson,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  EqPresetsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<bool>? isBuiltIn,
    Value<String>? bandsJson,
    Value<double>? preampDb,
    Value<String?>? configJson,
    Value<DateTime>? createdAt,
  }) {
    return EqPresetsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
      bandsJson: bandsJson ?? this.bandsJson,
      preampDb: preampDb ?? this.preampDb,
      configJson: configJson ?? this.configJson,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (isBuiltIn.present) {
      map['is_built_in'] = Variable<bool>(isBuiltIn.value);
    }
    if (bandsJson.present) {
      map['bands_json'] = Variable<String>(bandsJson.value);
    }
    if (preampDb.present) {
      map['preamp_db'] = Variable<double>(preampDb.value);
    }
    if (configJson.present) {
      map['config_json'] = Variable<String>(configJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EqPresetsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('isBuiltIn: $isBuiltIn, ')
          ..write('bandsJson: $bandsJson, ')
          ..write('preampDb: $preampDb, ')
          ..write('configJson: $configJson, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $SettingsTable extends Settings
    with TableInfo<$SettingsTable, SettingRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _scopeMeta = const VerificationMeta('scope');
  @override
  late final GeneratedColumn<String> scope = GeneratedColumn<String>(
    'scope',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('global'),
  );
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [scope, key, value, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<SettingRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('scope')) {
      context.handle(
        _scopeMeta,
        scope.isAcceptableOrUnknown(data['scope']!, _scopeMeta),
      );
    }
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {scope, key};
  @override
  SettingRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SettingRow(
      scope: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scope'],
      )!,
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $SettingsTable createAlias(String alias) {
    return $SettingsTable(attachedDatabase, alias);
  }
}

class SettingRow extends DataClass implements Insertable<SettingRow> {
  final String scope;
  final String key;
  final String value;
  final DateTime updatedAt;
  const SettingRow({
    required this.scope,
    required this.key,
    required this.value,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['scope'] = Variable<String>(scope);
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(
      scope: Value(scope),
      key: Value(key),
      value: Value(value),
      updatedAt: Value(updatedAt),
    );
  }

  factory SettingRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SettingRow(
      scope: serializer.fromJson<String>(json['scope']),
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'scope': serializer.toJson<String>(scope),
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  SettingRow copyWith({
    String? scope,
    String? key,
    String? value,
    DateTime? updatedAt,
  }) => SettingRow(
    scope: scope ?? this.scope,
    key: key ?? this.key,
    value: value ?? this.value,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  SettingRow copyWithCompanion(SettingsCompanion data) {
    return SettingRow(
      scope: data.scope.present ? data.scope.value : this.scope,
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SettingRow(')
          ..write('scope: $scope, ')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(scope, key, value, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SettingRow &&
          other.scope == this.scope &&
          other.key == this.key &&
          other.value == this.value &&
          other.updatedAt == this.updatedAt);
}

class SettingsCompanion extends UpdateCompanion<SettingRow> {
  final Value<String> scope;
  final Value<String> key;
  final Value<String> value;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const SettingsCompanion({
    this.scope = const Value.absent(),
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingsCompanion.insert({
    this.scope = const Value.absent(),
    required String key,
    required String value,
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<SettingRow> custom({
    Expression<String>? scope,
    Expression<String>? key,
    Expression<String>? value,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (scope != null) 'scope': scope,
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SettingsCompanion copyWith({
    Value<String>? scope,
    Value<String>? key,
    Value<String>? value,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return SettingsCompanion(
      scope: scope ?? this.scope,
      key: key ?? this.key,
      value: value ?? this.value,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (scope.present) {
      map['scope'] = Variable<String>(scope.value);
    }
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsCompanion(')
          ..write('scope: $scope, ')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ProfilesTable extends Profiles
    with TableInfo<$ProfilesTable, ProfileRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProfilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, isActive, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'profiles';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProfileRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ProfileRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProfileRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ProfilesTable createAlias(String alias) {
    return $ProfilesTable(attachedDatabase, alias);
  }
}

class ProfileRow extends DataClass implements Insertable<ProfileRow> {
  final int id;
  final String name;
  final bool isActive;
  final DateTime createdAt;
  const ProfileRow({
    required this.id,
    required this.name,
    required this.isActive,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['is_active'] = Variable<bool>(isActive);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ProfilesCompanion toCompanion(bool nullToAbsent) {
    return ProfilesCompanion(
      id: Value(id),
      name: Value(name),
      isActive: Value(isActive),
      createdAt: Value(createdAt),
    );
  }

  factory ProfileRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProfileRow(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'isActive': serializer.toJson<bool>(isActive),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  ProfileRow copyWith({
    int? id,
    String? name,
    bool? isActive,
    DateTime? createdAt,
  }) => ProfileRow(
    id: id ?? this.id,
    name: name ?? this.name,
    isActive: isActive ?? this.isActive,
    createdAt: createdAt ?? this.createdAt,
  );
  ProfileRow copyWithCompanion(ProfilesCompanion data) {
    return ProfileRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProfileRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('isActive: $isActive, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, isActive, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProfileRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.isActive == this.isActive &&
          other.createdAt == this.createdAt);
}

class ProfilesCompanion extends UpdateCompanion<ProfileRow> {
  final Value<int> id;
  final Value<String> name;
  final Value<bool> isActive;
  final Value<DateTime> createdAt;
  const ProfilesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.isActive = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  ProfilesCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.isActive = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : name = Value(name);
  static Insertable<ProfileRow> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<bool>? isActive,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (isActive != null) 'is_active': isActive,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  ProfilesCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<bool>? isActive,
    Value<DateTime>? createdAt,
  }) {
    return ProfilesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProfilesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('isActive: $isActive, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $LyricsTable extends Lyrics with TableInfo<$LyricsTable, LyricRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LyricsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _trackIdMeta = const VerificationMeta(
    'trackId',
  );
  @override
  late final GeneratedColumn<int> trackId = GeneratedColumn<int>(
    'track_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES tracks (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _syncedMeta = const VerificationMeta('synced');
  @override
  late final GeneratedColumn<bool> synced = GeneratedColumn<bool>(
    'synced',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("synced" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('local'),
  );
  static const VerificationMeta _fetchedAtMeta = const VerificationMeta(
    'fetchedAt',
  );
  @override
  late final GeneratedColumn<DateTime> fetchedAt = GeneratedColumn<DateTime>(
    'fetched_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    trackId,
    content,
    synced,
    source,
    fetchedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'lyrics';
  @override
  VerificationContext validateIntegrity(
    Insertable<LyricRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('track_id')) {
      context.handle(
        _trackIdMeta,
        trackId.isAcceptableOrUnknown(data['track_id']!, _trackIdMeta),
      );
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('synced')) {
      context.handle(
        _syncedMeta,
        synced.isAcceptableOrUnknown(data['synced']!, _syncedMeta),
      );
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    }
    if (data.containsKey('fetched_at')) {
      context.handle(
        _fetchedAtMeta,
        fetchedAt.isAcceptableOrUnknown(data['fetched_at']!, _fetchedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {trackId};
  @override
  LyricRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LyricRow(
      trackId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}track_id'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      synced: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}synced'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      fetchedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}fetched_at'],
      )!,
    );
  }

  @override
  $LyricsTable createAlias(String alias) {
    return $LyricsTable(attachedDatabase, alias);
  }
}

class LyricRow extends DataClass implements Insertable<LyricRow> {
  final int trackId;
  final String content;
  final bool synced;
  final String source;
  final DateTime fetchedAt;
  const LyricRow({
    required this.trackId,
    required this.content,
    required this.synced,
    required this.source,
    required this.fetchedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['track_id'] = Variable<int>(trackId);
    map['content'] = Variable<String>(content);
    map['synced'] = Variable<bool>(synced);
    map['source'] = Variable<String>(source);
    map['fetched_at'] = Variable<DateTime>(fetchedAt);
    return map;
  }

  LyricsCompanion toCompanion(bool nullToAbsent) {
    return LyricsCompanion(
      trackId: Value(trackId),
      content: Value(content),
      synced: Value(synced),
      source: Value(source),
      fetchedAt: Value(fetchedAt),
    );
  }

  factory LyricRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LyricRow(
      trackId: serializer.fromJson<int>(json['trackId']),
      content: serializer.fromJson<String>(json['content']),
      synced: serializer.fromJson<bool>(json['synced']),
      source: serializer.fromJson<String>(json['source']),
      fetchedAt: serializer.fromJson<DateTime>(json['fetchedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'trackId': serializer.toJson<int>(trackId),
      'content': serializer.toJson<String>(content),
      'synced': serializer.toJson<bool>(synced),
      'source': serializer.toJson<String>(source),
      'fetchedAt': serializer.toJson<DateTime>(fetchedAt),
    };
  }

  LyricRow copyWith({
    int? trackId,
    String? content,
    bool? synced,
    String? source,
    DateTime? fetchedAt,
  }) => LyricRow(
    trackId: trackId ?? this.trackId,
    content: content ?? this.content,
    synced: synced ?? this.synced,
    source: source ?? this.source,
    fetchedAt: fetchedAt ?? this.fetchedAt,
  );
  LyricRow copyWithCompanion(LyricsCompanion data) {
    return LyricRow(
      trackId: data.trackId.present ? data.trackId.value : this.trackId,
      content: data.content.present ? data.content.value : this.content,
      synced: data.synced.present ? data.synced.value : this.synced,
      source: data.source.present ? data.source.value : this.source,
      fetchedAt: data.fetchedAt.present ? data.fetchedAt.value : this.fetchedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LyricRow(')
          ..write('trackId: $trackId, ')
          ..write('content: $content, ')
          ..write('synced: $synced, ')
          ..write('source: $source, ')
          ..write('fetchedAt: $fetchedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(trackId, content, synced, source, fetchedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LyricRow &&
          other.trackId == this.trackId &&
          other.content == this.content &&
          other.synced == this.synced &&
          other.source == this.source &&
          other.fetchedAt == this.fetchedAt);
}

class LyricsCompanion extends UpdateCompanion<LyricRow> {
  final Value<int> trackId;
  final Value<String> content;
  final Value<bool> synced;
  final Value<String> source;
  final Value<DateTime> fetchedAt;
  const LyricsCompanion({
    this.trackId = const Value.absent(),
    this.content = const Value.absent(),
    this.synced = const Value.absent(),
    this.source = const Value.absent(),
    this.fetchedAt = const Value.absent(),
  });
  LyricsCompanion.insert({
    this.trackId = const Value.absent(),
    required String content,
    this.synced = const Value.absent(),
    this.source = const Value.absent(),
    this.fetchedAt = const Value.absent(),
  }) : content = Value(content);
  static Insertable<LyricRow> custom({
    Expression<int>? trackId,
    Expression<String>? content,
    Expression<bool>? synced,
    Expression<String>? source,
    Expression<DateTime>? fetchedAt,
  }) {
    return RawValuesInsertable({
      if (trackId != null) 'track_id': trackId,
      if (content != null) 'content': content,
      if (synced != null) 'synced': synced,
      if (source != null) 'source': source,
      if (fetchedAt != null) 'fetched_at': fetchedAt,
    });
  }

  LyricsCompanion copyWith({
    Value<int>? trackId,
    Value<String>? content,
    Value<bool>? synced,
    Value<String>? source,
    Value<DateTime>? fetchedAt,
  }) {
    return LyricsCompanion(
      trackId: trackId ?? this.trackId,
      content: content ?? this.content,
      synced: synced ?? this.synced,
      source: source ?? this.source,
      fetchedAt: fetchedAt ?? this.fetchedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (trackId.present) {
      map['track_id'] = Variable<int>(trackId.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (synced.present) {
      map['synced'] = Variable<bool>(synced.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (fetchedAt.present) {
      map['fetched_at'] = Variable<DateTime>(fetchedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LyricsCompanion(')
          ..write('trackId: $trackId, ')
          ..write('content: $content, ')
          ..write('synced: $synced, ')
          ..write('source: $source, ')
          ..write('fetchedAt: $fetchedAt')
          ..write(')'))
        .toString();
  }
}

class $PluginsTable extends Plugins with TableInfo<$PluginsTable, PluginRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PluginsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<String> version = GeneratedColumn<String>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _enabledMeta = const VerificationMeta(
    'enabled',
  );
  @override
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
    'enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _configJsonMeta = const VerificationMeta(
    'configJson',
  );
  @override
  late final GeneratedColumn<String> configJson = GeneratedColumn<String>(
    'config_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _installedAtMeta = const VerificationMeta(
    'installedAt',
  );
  @override
  late final GeneratedColumn<DateTime> installedAt = GeneratedColumn<DateTime>(
    'installed_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    version,
    enabled,
    configJson,
    installedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'plugins';
  @override
  VerificationContext validateIntegrity(
    Insertable<PluginRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    } else if (isInserting) {
      context.missing(_versionMeta);
    }
    if (data.containsKey('enabled')) {
      context.handle(
        _enabledMeta,
        enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta),
      );
    }
    if (data.containsKey('config_json')) {
      context.handle(
        _configJsonMeta,
        configJson.isAcceptableOrUnknown(data['config_json']!, _configJsonMeta),
      );
    }
    if (data.containsKey('installed_at')) {
      context.handle(
        _installedAtMeta,
        installedAt.isAcceptableOrUnknown(
          data['installed_at']!,
          _installedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PluginRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PluginRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}version'],
      )!,
      enabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}enabled'],
      )!,
      configJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}config_json'],
      ),
      installedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}installed_at'],
      )!,
    );
  }

  @override
  $PluginsTable createAlias(String alias) {
    return $PluginsTable(attachedDatabase, alias);
  }
}

class PluginRow extends DataClass implements Insertable<PluginRow> {
  final int id;
  final String name;
  final String version;
  final bool enabled;
  final String? configJson;
  final DateTime installedAt;
  const PluginRow({
    required this.id,
    required this.name,
    required this.version,
    required this.enabled,
    this.configJson,
    required this.installedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['version'] = Variable<String>(version);
    map['enabled'] = Variable<bool>(enabled);
    if (!nullToAbsent || configJson != null) {
      map['config_json'] = Variable<String>(configJson);
    }
    map['installed_at'] = Variable<DateTime>(installedAt);
    return map;
  }

  PluginsCompanion toCompanion(bool nullToAbsent) {
    return PluginsCompanion(
      id: Value(id),
      name: Value(name),
      version: Value(version),
      enabled: Value(enabled),
      configJson: configJson == null && nullToAbsent
          ? const Value.absent()
          : Value(configJson),
      installedAt: Value(installedAt),
    );
  }

  factory PluginRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PluginRow(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      version: serializer.fromJson<String>(json['version']),
      enabled: serializer.fromJson<bool>(json['enabled']),
      configJson: serializer.fromJson<String?>(json['configJson']),
      installedAt: serializer.fromJson<DateTime>(json['installedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'version': serializer.toJson<String>(version),
      'enabled': serializer.toJson<bool>(enabled),
      'configJson': serializer.toJson<String?>(configJson),
      'installedAt': serializer.toJson<DateTime>(installedAt),
    };
  }

  PluginRow copyWith({
    int? id,
    String? name,
    String? version,
    bool? enabled,
    Value<String?> configJson = const Value.absent(),
    DateTime? installedAt,
  }) => PluginRow(
    id: id ?? this.id,
    name: name ?? this.name,
    version: version ?? this.version,
    enabled: enabled ?? this.enabled,
    configJson: configJson.present ? configJson.value : this.configJson,
    installedAt: installedAt ?? this.installedAt,
  );
  PluginRow copyWithCompanion(PluginsCompanion data) {
    return PluginRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      version: data.version.present ? data.version.value : this.version,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      configJson: data.configJson.present
          ? data.configJson.value
          : this.configJson,
      installedAt: data.installedAt.present
          ? data.installedAt.value
          : this.installedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PluginRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('version: $version, ')
          ..write('enabled: $enabled, ')
          ..write('configJson: $configJson, ')
          ..write('installedAt: $installedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, version, enabled, configJson, installedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PluginRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.version == this.version &&
          other.enabled == this.enabled &&
          other.configJson == this.configJson &&
          other.installedAt == this.installedAt);
}

class PluginsCompanion extends UpdateCompanion<PluginRow> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> version;
  final Value<bool> enabled;
  final Value<String?> configJson;
  final Value<DateTime> installedAt;
  const PluginsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.version = const Value.absent(),
    this.enabled = const Value.absent(),
    this.configJson = const Value.absent(),
    this.installedAt = const Value.absent(),
  });
  PluginsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required String version,
    this.enabled = const Value.absent(),
    this.configJson = const Value.absent(),
    this.installedAt = const Value.absent(),
  }) : name = Value(name),
       version = Value(version);
  static Insertable<PluginRow> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? version,
    Expression<bool>? enabled,
    Expression<String>? configJson,
    Expression<DateTime>? installedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (version != null) 'version': version,
      if (enabled != null) 'enabled': enabled,
      if (configJson != null) 'config_json': configJson,
      if (installedAt != null) 'installed_at': installedAt,
    });
  }

  PluginsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? version,
    Value<bool>? enabled,
    Value<String?>? configJson,
    Value<DateTime>? installedAt,
  }) {
    return PluginsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      version: version ?? this.version,
      enabled: enabled ?? this.enabled,
      configJson: configJson ?? this.configJson,
      installedAt: installedAt ?? this.installedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (version.present) {
      map['version'] = Variable<String>(version.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    if (configJson.present) {
      map['config_json'] = Variable<String>(configJson.value);
    }
    if (installedAt.present) {
      map['installed_at'] = Variable<DateTime>(installedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PluginsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('version: $version, ')
          ..write('enabled: $enabled, ')
          ..write('configJson: $configJson, ')
          ..write('installedAt: $installedAt')
          ..write(')'))
        .toString();
  }
}

class $OnlineReferencesTable extends OnlineReferences
    with TableInfo<$OnlineReferencesTable, OnlineReferenceRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OnlineReferencesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _externalIdMeta = const VerificationMeta(
    'externalId',
  );
  @override
  late final GeneratedColumn<String> externalId = GeneratedColumn<String>(
    'external_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nativeIdMeta = const VerificationMeta(
    'nativeId',
  );
  @override
  late final GeneratedColumn<String> nativeId = GeneratedColumn<String>(
    'native_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _subtitleMeta = const VerificationMeta(
    'subtitle',
  );
  @override
  late final GeneratedColumn<String> subtitle = GeneratedColumn<String>(
    'subtitle',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _artworkPathMeta = const VerificationMeta(
    'artworkPath',
  );
  @override
  late final GeneratedColumn<String> artworkPath = GeneratedColumn<String>(
    'artwork_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _permalinkMeta = const VerificationMeta(
    'permalink',
  );
  @override
  late final GeneratedColumn<String> permalink = GeneratedColumn<String>(
    'permalink',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _trackCountMeta = const VerificationMeta(
    'trackCount',
  );
  @override
  late final GeneratedColumn<int> trackCount = GeneratedColumn<int>(
    'track_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _continuationMeta = const VerificationMeta(
    'continuation',
  );
  @override
  late final GeneratedColumn<String> continuation = GeneratedColumn<String>(
    'continuation',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _hasMoreMeta = const VerificationMeta(
    'hasMore',
  );
  @override
  late final GeneratedColumn<bool> hasMore = GeneratedColumn<bool>(
    'has_more',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("has_more" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _syncedAtMeta = const VerificationMeta(
    'syncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> syncedAt = GeneratedColumn<DateTime>(
    'synced_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastSuccessfulSyncAtMeta =
      const VerificationMeta('lastSuccessfulSyncAt');
  @override
  late final GeneratedColumn<DateTime> lastSuccessfulSyncAt =
      GeneratedColumn<DateTime>(
        'last_successful_sync_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isFavoriteMeta = const VerificationMeta(
    'isFavorite',
  );
  @override
  late final GeneratedColumn<bool> isFavorite = GeneratedColumn<bool>(
    'is_favorite',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_favorite" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _playCountMeta = const VerificationMeta(
    'playCount',
  );
  @override
  late final GeneratedColumn<int> playCount = GeneratedColumn<int>(
    'play_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    externalId,
    source,
    kind,
    nativeId,
    title,
    subtitle,
    artworkPath,
    permalink,
    trackCount,
    continuation,
    hasMore,
    syncedAt,
    lastSuccessfulSyncAt,
    lastError,
    isFavorite,
    playCount,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'online_references';
  @override
  VerificationContext validateIntegrity(
    Insertable<OnlineReferenceRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('external_id')) {
      context.handle(
        _externalIdMeta,
        externalId.isAcceptableOrUnknown(data['external_id']!, _externalIdMeta),
      );
    } else if (isInserting) {
      context.missing(_externalIdMeta);
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('native_id')) {
      context.handle(
        _nativeIdMeta,
        nativeId.isAcceptableOrUnknown(data['native_id']!, _nativeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_nativeIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('subtitle')) {
      context.handle(
        _subtitleMeta,
        subtitle.isAcceptableOrUnknown(data['subtitle']!, _subtitleMeta),
      );
    }
    if (data.containsKey('artwork_path')) {
      context.handle(
        _artworkPathMeta,
        artworkPath.isAcceptableOrUnknown(
          data['artwork_path']!,
          _artworkPathMeta,
        ),
      );
    }
    if (data.containsKey('permalink')) {
      context.handle(
        _permalinkMeta,
        permalink.isAcceptableOrUnknown(data['permalink']!, _permalinkMeta),
      );
    }
    if (data.containsKey('track_count')) {
      context.handle(
        _trackCountMeta,
        trackCount.isAcceptableOrUnknown(data['track_count']!, _trackCountMeta),
      );
    }
    if (data.containsKey('continuation')) {
      context.handle(
        _continuationMeta,
        continuation.isAcceptableOrUnknown(
          data['continuation']!,
          _continuationMeta,
        ),
      );
    }
    if (data.containsKey('has_more')) {
      context.handle(
        _hasMoreMeta,
        hasMore.isAcceptableOrUnknown(data['has_more']!, _hasMoreMeta),
      );
    }
    if (data.containsKey('synced_at')) {
      context.handle(
        _syncedAtMeta,
        syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta),
      );
    }
    if (data.containsKey('last_successful_sync_at')) {
      context.handle(
        _lastSuccessfulSyncAtMeta,
        lastSuccessfulSyncAt.isAcceptableOrUnknown(
          data['last_successful_sync_at']!,
          _lastSuccessfulSyncAtMeta,
        ),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    if (data.containsKey('is_favorite')) {
      context.handle(
        _isFavoriteMeta,
        isFavorite.isAcceptableOrUnknown(data['is_favorite']!, _isFavoriteMeta),
      );
    }
    if (data.containsKey('play_count')) {
      context.handle(
        _playCountMeta,
        playCount.isAcceptableOrUnknown(data['play_count']!, _playCountMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {externalId};
  @override
  OnlineReferenceRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OnlineReferenceRow(
      externalId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}external_id'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      nativeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}native_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      subtitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subtitle'],
      )!,
      artworkPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}artwork_path'],
      ),
      permalink: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}permalink'],
      ),
      trackCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}track_count'],
      )!,
      continuation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}continuation'],
      ),
      hasMore: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}has_more'],
      )!,
      syncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}synced_at'],
      ),
      lastSuccessfulSyncAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_successful_sync_at'],
      ),
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
      isFavorite: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_favorite'],
      )!,
      playCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}play_count'],
      )!,
    );
  }

  @override
  $OnlineReferencesTable createAlias(String alias) {
    return $OnlineReferencesTable(attachedDatabase, alias);
  }
}

class OnlineReferenceRow extends DataClass
    implements Insertable<OnlineReferenceRow> {
  final String externalId;
  final String source;
  final String kind;
  final String nativeId;
  final String title;
  final String subtitle;
  final String? artworkPath;
  final String? permalink;
  final int trackCount;
  final String? continuation;
  final bool hasMore;
  final DateTime? syncedAt;
  final DateTime? lastSuccessfulSyncAt;
  final String? lastError;

  /// Estado local: nunca lo toca una sincronización remota.
  final bool isFavorite;
  final int playCount;
  const OnlineReferenceRow({
    required this.externalId,
    required this.source,
    required this.kind,
    required this.nativeId,
    required this.title,
    required this.subtitle,
    this.artworkPath,
    this.permalink,
    required this.trackCount,
    this.continuation,
    required this.hasMore,
    this.syncedAt,
    this.lastSuccessfulSyncAt,
    this.lastError,
    required this.isFavorite,
    required this.playCount,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['external_id'] = Variable<String>(externalId);
    map['source'] = Variable<String>(source);
    map['kind'] = Variable<String>(kind);
    map['native_id'] = Variable<String>(nativeId);
    map['title'] = Variable<String>(title);
    map['subtitle'] = Variable<String>(subtitle);
    if (!nullToAbsent || artworkPath != null) {
      map['artwork_path'] = Variable<String>(artworkPath);
    }
    if (!nullToAbsent || permalink != null) {
      map['permalink'] = Variable<String>(permalink);
    }
    map['track_count'] = Variable<int>(trackCount);
    if (!nullToAbsent || continuation != null) {
      map['continuation'] = Variable<String>(continuation);
    }
    map['has_more'] = Variable<bool>(hasMore);
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<DateTime>(syncedAt);
    }
    if (!nullToAbsent || lastSuccessfulSyncAt != null) {
      map['last_successful_sync_at'] = Variable<DateTime>(lastSuccessfulSyncAt);
    }
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    map['is_favorite'] = Variable<bool>(isFavorite);
    map['play_count'] = Variable<int>(playCount);
    return map;
  }

  OnlineReferencesCompanion toCompanion(bool nullToAbsent) {
    return OnlineReferencesCompanion(
      externalId: Value(externalId),
      source: Value(source),
      kind: Value(kind),
      nativeId: Value(nativeId),
      title: Value(title),
      subtitle: Value(subtitle),
      artworkPath: artworkPath == null && nullToAbsent
          ? const Value.absent()
          : Value(artworkPath),
      permalink: permalink == null && nullToAbsent
          ? const Value.absent()
          : Value(permalink),
      trackCount: Value(trackCount),
      continuation: continuation == null && nullToAbsent
          ? const Value.absent()
          : Value(continuation),
      hasMore: Value(hasMore),
      syncedAt: syncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedAt),
      lastSuccessfulSyncAt: lastSuccessfulSyncAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSuccessfulSyncAt),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      isFavorite: Value(isFavorite),
      playCount: Value(playCount),
    );
  }

  factory OnlineReferenceRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OnlineReferenceRow(
      externalId: serializer.fromJson<String>(json['externalId']),
      source: serializer.fromJson<String>(json['source']),
      kind: serializer.fromJson<String>(json['kind']),
      nativeId: serializer.fromJson<String>(json['nativeId']),
      title: serializer.fromJson<String>(json['title']),
      subtitle: serializer.fromJson<String>(json['subtitle']),
      artworkPath: serializer.fromJson<String?>(json['artworkPath']),
      permalink: serializer.fromJson<String?>(json['permalink']),
      trackCount: serializer.fromJson<int>(json['trackCount']),
      continuation: serializer.fromJson<String?>(json['continuation']),
      hasMore: serializer.fromJson<bool>(json['hasMore']),
      syncedAt: serializer.fromJson<DateTime?>(json['syncedAt']),
      lastSuccessfulSyncAt: serializer.fromJson<DateTime?>(
        json['lastSuccessfulSyncAt'],
      ),
      lastError: serializer.fromJson<String?>(json['lastError']),
      isFavorite: serializer.fromJson<bool>(json['isFavorite']),
      playCount: serializer.fromJson<int>(json['playCount']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'externalId': serializer.toJson<String>(externalId),
      'source': serializer.toJson<String>(source),
      'kind': serializer.toJson<String>(kind),
      'nativeId': serializer.toJson<String>(nativeId),
      'title': serializer.toJson<String>(title),
      'subtitle': serializer.toJson<String>(subtitle),
      'artworkPath': serializer.toJson<String?>(artworkPath),
      'permalink': serializer.toJson<String?>(permalink),
      'trackCount': serializer.toJson<int>(trackCount),
      'continuation': serializer.toJson<String?>(continuation),
      'hasMore': serializer.toJson<bool>(hasMore),
      'syncedAt': serializer.toJson<DateTime?>(syncedAt),
      'lastSuccessfulSyncAt': serializer.toJson<DateTime?>(
        lastSuccessfulSyncAt,
      ),
      'lastError': serializer.toJson<String?>(lastError),
      'isFavorite': serializer.toJson<bool>(isFavorite),
      'playCount': serializer.toJson<int>(playCount),
    };
  }

  OnlineReferenceRow copyWith({
    String? externalId,
    String? source,
    String? kind,
    String? nativeId,
    String? title,
    String? subtitle,
    Value<String?> artworkPath = const Value.absent(),
    Value<String?> permalink = const Value.absent(),
    int? trackCount,
    Value<String?> continuation = const Value.absent(),
    bool? hasMore,
    Value<DateTime?> syncedAt = const Value.absent(),
    Value<DateTime?> lastSuccessfulSyncAt = const Value.absent(),
    Value<String?> lastError = const Value.absent(),
    bool? isFavorite,
    int? playCount,
  }) => OnlineReferenceRow(
    externalId: externalId ?? this.externalId,
    source: source ?? this.source,
    kind: kind ?? this.kind,
    nativeId: nativeId ?? this.nativeId,
    title: title ?? this.title,
    subtitle: subtitle ?? this.subtitle,
    artworkPath: artworkPath.present ? artworkPath.value : this.artworkPath,
    permalink: permalink.present ? permalink.value : this.permalink,
    trackCount: trackCount ?? this.trackCount,
    continuation: continuation.present ? continuation.value : this.continuation,
    hasMore: hasMore ?? this.hasMore,
    syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
    lastSuccessfulSyncAt: lastSuccessfulSyncAt.present
        ? lastSuccessfulSyncAt.value
        : this.lastSuccessfulSyncAt,
    lastError: lastError.present ? lastError.value : this.lastError,
    isFavorite: isFavorite ?? this.isFavorite,
    playCount: playCount ?? this.playCount,
  );
  OnlineReferenceRow copyWithCompanion(OnlineReferencesCompanion data) {
    return OnlineReferenceRow(
      externalId: data.externalId.present
          ? data.externalId.value
          : this.externalId,
      source: data.source.present ? data.source.value : this.source,
      kind: data.kind.present ? data.kind.value : this.kind,
      nativeId: data.nativeId.present ? data.nativeId.value : this.nativeId,
      title: data.title.present ? data.title.value : this.title,
      subtitle: data.subtitle.present ? data.subtitle.value : this.subtitle,
      artworkPath: data.artworkPath.present
          ? data.artworkPath.value
          : this.artworkPath,
      permalink: data.permalink.present ? data.permalink.value : this.permalink,
      trackCount: data.trackCount.present
          ? data.trackCount.value
          : this.trackCount,
      continuation: data.continuation.present
          ? data.continuation.value
          : this.continuation,
      hasMore: data.hasMore.present ? data.hasMore.value : this.hasMore,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
      lastSuccessfulSyncAt: data.lastSuccessfulSyncAt.present
          ? data.lastSuccessfulSyncAt.value
          : this.lastSuccessfulSyncAt,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      isFavorite: data.isFavorite.present
          ? data.isFavorite.value
          : this.isFavorite,
      playCount: data.playCount.present ? data.playCount.value : this.playCount,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OnlineReferenceRow(')
          ..write('externalId: $externalId, ')
          ..write('source: $source, ')
          ..write('kind: $kind, ')
          ..write('nativeId: $nativeId, ')
          ..write('title: $title, ')
          ..write('subtitle: $subtitle, ')
          ..write('artworkPath: $artworkPath, ')
          ..write('permalink: $permalink, ')
          ..write('trackCount: $trackCount, ')
          ..write('continuation: $continuation, ')
          ..write('hasMore: $hasMore, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('lastSuccessfulSyncAt: $lastSuccessfulSyncAt, ')
          ..write('lastError: $lastError, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('playCount: $playCount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    externalId,
    source,
    kind,
    nativeId,
    title,
    subtitle,
    artworkPath,
    permalink,
    trackCount,
    continuation,
    hasMore,
    syncedAt,
    lastSuccessfulSyncAt,
    lastError,
    isFavorite,
    playCount,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OnlineReferenceRow &&
          other.externalId == this.externalId &&
          other.source == this.source &&
          other.kind == this.kind &&
          other.nativeId == this.nativeId &&
          other.title == this.title &&
          other.subtitle == this.subtitle &&
          other.artworkPath == this.artworkPath &&
          other.permalink == this.permalink &&
          other.trackCount == this.trackCount &&
          other.continuation == this.continuation &&
          other.hasMore == this.hasMore &&
          other.syncedAt == this.syncedAt &&
          other.lastSuccessfulSyncAt == this.lastSuccessfulSyncAt &&
          other.lastError == this.lastError &&
          other.isFavorite == this.isFavorite &&
          other.playCount == this.playCount);
}

class OnlineReferencesCompanion extends UpdateCompanion<OnlineReferenceRow> {
  final Value<String> externalId;
  final Value<String> source;
  final Value<String> kind;
  final Value<String> nativeId;
  final Value<String> title;
  final Value<String> subtitle;
  final Value<String?> artworkPath;
  final Value<String?> permalink;
  final Value<int> trackCount;
  final Value<String?> continuation;
  final Value<bool> hasMore;
  final Value<DateTime?> syncedAt;
  final Value<DateTime?> lastSuccessfulSyncAt;
  final Value<String?> lastError;
  final Value<bool> isFavorite;
  final Value<int> playCount;
  final Value<int> rowid;
  const OnlineReferencesCompanion({
    this.externalId = const Value.absent(),
    this.source = const Value.absent(),
    this.kind = const Value.absent(),
    this.nativeId = const Value.absent(),
    this.title = const Value.absent(),
    this.subtitle = const Value.absent(),
    this.artworkPath = const Value.absent(),
    this.permalink = const Value.absent(),
    this.trackCount = const Value.absent(),
    this.continuation = const Value.absent(),
    this.hasMore = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.lastSuccessfulSyncAt = const Value.absent(),
    this.lastError = const Value.absent(),
    this.isFavorite = const Value.absent(),
    this.playCount = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OnlineReferencesCompanion.insert({
    required String externalId,
    required String source,
    required String kind,
    required String nativeId,
    required String title,
    this.subtitle = const Value.absent(),
    this.artworkPath = const Value.absent(),
    this.permalink = const Value.absent(),
    this.trackCount = const Value.absent(),
    this.continuation = const Value.absent(),
    this.hasMore = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.lastSuccessfulSyncAt = const Value.absent(),
    this.lastError = const Value.absent(),
    this.isFavorite = const Value.absent(),
    this.playCount = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : externalId = Value(externalId),
       source = Value(source),
       kind = Value(kind),
       nativeId = Value(nativeId),
       title = Value(title);
  static Insertable<OnlineReferenceRow> custom({
    Expression<String>? externalId,
    Expression<String>? source,
    Expression<String>? kind,
    Expression<String>? nativeId,
    Expression<String>? title,
    Expression<String>? subtitle,
    Expression<String>? artworkPath,
    Expression<String>? permalink,
    Expression<int>? trackCount,
    Expression<String>? continuation,
    Expression<bool>? hasMore,
    Expression<DateTime>? syncedAt,
    Expression<DateTime>? lastSuccessfulSyncAt,
    Expression<String>? lastError,
    Expression<bool>? isFavorite,
    Expression<int>? playCount,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (externalId != null) 'external_id': externalId,
      if (source != null) 'source': source,
      if (kind != null) 'kind': kind,
      if (nativeId != null) 'native_id': nativeId,
      if (title != null) 'title': title,
      if (subtitle != null) 'subtitle': subtitle,
      if (artworkPath != null) 'artwork_path': artworkPath,
      if (permalink != null) 'permalink': permalink,
      if (trackCount != null) 'track_count': trackCount,
      if (continuation != null) 'continuation': continuation,
      if (hasMore != null) 'has_more': hasMore,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (lastSuccessfulSyncAt != null)
        'last_successful_sync_at': lastSuccessfulSyncAt,
      if (lastError != null) 'last_error': lastError,
      if (isFavorite != null) 'is_favorite': isFavorite,
      if (playCount != null) 'play_count': playCount,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OnlineReferencesCompanion copyWith({
    Value<String>? externalId,
    Value<String>? source,
    Value<String>? kind,
    Value<String>? nativeId,
    Value<String>? title,
    Value<String>? subtitle,
    Value<String?>? artworkPath,
    Value<String?>? permalink,
    Value<int>? trackCount,
    Value<String?>? continuation,
    Value<bool>? hasMore,
    Value<DateTime?>? syncedAt,
    Value<DateTime?>? lastSuccessfulSyncAt,
    Value<String?>? lastError,
    Value<bool>? isFavorite,
    Value<int>? playCount,
    Value<int>? rowid,
  }) {
    return OnlineReferencesCompanion(
      externalId: externalId ?? this.externalId,
      source: source ?? this.source,
      kind: kind ?? this.kind,
      nativeId: nativeId ?? this.nativeId,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      artworkPath: artworkPath ?? this.artworkPath,
      permalink: permalink ?? this.permalink,
      trackCount: trackCount ?? this.trackCount,
      continuation: continuation ?? this.continuation,
      hasMore: hasMore ?? this.hasMore,
      syncedAt: syncedAt ?? this.syncedAt,
      lastSuccessfulSyncAt: lastSuccessfulSyncAt ?? this.lastSuccessfulSyncAt,
      lastError: lastError ?? this.lastError,
      isFavorite: isFavorite ?? this.isFavorite,
      playCount: playCount ?? this.playCount,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (externalId.present) {
      map['external_id'] = Variable<String>(externalId.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (nativeId.present) {
      map['native_id'] = Variable<String>(nativeId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (subtitle.present) {
      map['subtitle'] = Variable<String>(subtitle.value);
    }
    if (artworkPath.present) {
      map['artwork_path'] = Variable<String>(artworkPath.value);
    }
    if (permalink.present) {
      map['permalink'] = Variable<String>(permalink.value);
    }
    if (trackCount.present) {
      map['track_count'] = Variable<int>(trackCount.value);
    }
    if (continuation.present) {
      map['continuation'] = Variable<String>(continuation.value);
    }
    if (hasMore.present) {
      map['has_more'] = Variable<bool>(hasMore.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<DateTime>(syncedAt.value);
    }
    if (lastSuccessfulSyncAt.present) {
      map['last_successful_sync_at'] = Variable<DateTime>(
        lastSuccessfulSyncAt.value,
      );
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (isFavorite.present) {
      map['is_favorite'] = Variable<bool>(isFavorite.value);
    }
    if (playCount.present) {
      map['play_count'] = Variable<int>(playCount.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OnlineReferencesCompanion(')
          ..write('externalId: $externalId, ')
          ..write('source: $source, ')
          ..write('kind: $kind, ')
          ..write('nativeId: $nativeId, ')
          ..write('title: $title, ')
          ..write('subtitle: $subtitle, ')
          ..write('artworkPath: $artworkPath, ')
          ..write('permalink: $permalink, ')
          ..write('trackCount: $trackCount, ')
          ..write('continuation: $continuation, ')
          ..write('hasMore: $hasMore, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('lastSuccessfulSyncAt: $lastSuccessfulSyncAt, ')
          ..write('lastError: $lastError, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('playCount: $playCount, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OnlineReferenceTracksTable extends OnlineReferenceTracks
    with TableInfo<$OnlineReferenceTracksTable, OnlineReferenceTrackRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OnlineReferenceTracksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _referenceIdMeta = const VerificationMeta(
    'referenceId',
  );
  @override
  late final GeneratedColumn<String> referenceId = GeneratedColumn<String>(
    'reference_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _externalIdMeta = const VerificationMeta(
    'externalId',
  );
  @override
  late final GeneratedColumn<String> externalId = GeneratedColumn<String>(
    'external_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
    'source_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _artistMeta = const VerificationMeta('artist');
  @override
  late final GeneratedColumn<String> artist = GeneratedColumn<String>(
    'artist',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _albumMeta = const VerificationMeta('album');
  @override
  late final GeneratedColumn<String> album = GeneratedColumn<String>(
    'album',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    referenceId,
    externalId,
    source,
    sourceId,
    title,
    artist,
    album,
    durationMs,
    position,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'online_reference_tracks';
  @override
  VerificationContext validateIntegrity(
    Insertable<OnlineReferenceTrackRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('reference_id')) {
      context.handle(
        _referenceIdMeta,
        referenceId.isAcceptableOrUnknown(
          data['reference_id']!,
          _referenceIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_referenceIdMeta);
    }
    if (data.containsKey('external_id')) {
      context.handle(
        _externalIdMeta,
        externalId.isAcceptableOrUnknown(data['external_id']!, _externalIdMeta),
      );
    } else if (isInserting) {
      context.missing(_externalIdMeta);
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('artist')) {
      context.handle(
        _artistMeta,
        artist.isAcceptableOrUnknown(data['artist']!, _artistMeta),
      );
    } else if (isInserting) {
      context.missing(_artistMeta);
    }
    if (data.containsKey('album')) {
      context.handle(
        _albumMeta,
        album.isAcceptableOrUnknown(data['album']!, _albumMeta),
      );
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {referenceId, externalId};
  @override
  OnlineReferenceTrackRow map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OnlineReferenceTrackRow(
      referenceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reference_id'],
      )!,
      externalId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}external_id'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      artist: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}artist'],
      )!,
      album: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}album'],
      )!,
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
    );
  }

  @override
  $OnlineReferenceTracksTable createAlias(String alias) {
    return $OnlineReferenceTracksTable(attachedDatabase, alias);
  }
}

class OnlineReferenceTrackRow extends DataClass
    implements Insertable<OnlineReferenceTrackRow> {
  final String referenceId;
  final String externalId;
  final String source;
  final String sourceId;
  final String title;
  final String artist;
  final String album;
  final int durationMs;
  final int position;
  const OnlineReferenceTrackRow({
    required this.referenceId,
    required this.externalId,
    required this.source,
    required this.sourceId,
    required this.title,
    required this.artist,
    required this.album,
    required this.durationMs,
    required this.position,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['reference_id'] = Variable<String>(referenceId);
    map['external_id'] = Variable<String>(externalId);
    map['source'] = Variable<String>(source);
    map['source_id'] = Variable<String>(sourceId);
    map['title'] = Variable<String>(title);
    map['artist'] = Variable<String>(artist);
    map['album'] = Variable<String>(album);
    map['duration_ms'] = Variable<int>(durationMs);
    map['position'] = Variable<int>(position);
    return map;
  }

  OnlineReferenceTracksCompanion toCompanion(bool nullToAbsent) {
    return OnlineReferenceTracksCompanion(
      referenceId: Value(referenceId),
      externalId: Value(externalId),
      source: Value(source),
      sourceId: Value(sourceId),
      title: Value(title),
      artist: Value(artist),
      album: Value(album),
      durationMs: Value(durationMs),
      position: Value(position),
    );
  }

  factory OnlineReferenceTrackRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OnlineReferenceTrackRow(
      referenceId: serializer.fromJson<String>(json['referenceId']),
      externalId: serializer.fromJson<String>(json['externalId']),
      source: serializer.fromJson<String>(json['source']),
      sourceId: serializer.fromJson<String>(json['sourceId']),
      title: serializer.fromJson<String>(json['title']),
      artist: serializer.fromJson<String>(json['artist']),
      album: serializer.fromJson<String>(json['album']),
      durationMs: serializer.fromJson<int>(json['durationMs']),
      position: serializer.fromJson<int>(json['position']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'referenceId': serializer.toJson<String>(referenceId),
      'externalId': serializer.toJson<String>(externalId),
      'source': serializer.toJson<String>(source),
      'sourceId': serializer.toJson<String>(sourceId),
      'title': serializer.toJson<String>(title),
      'artist': serializer.toJson<String>(artist),
      'album': serializer.toJson<String>(album),
      'durationMs': serializer.toJson<int>(durationMs),
      'position': serializer.toJson<int>(position),
    };
  }

  OnlineReferenceTrackRow copyWith({
    String? referenceId,
    String? externalId,
    String? source,
    String? sourceId,
    String? title,
    String? artist,
    String? album,
    int? durationMs,
    int? position,
  }) => OnlineReferenceTrackRow(
    referenceId: referenceId ?? this.referenceId,
    externalId: externalId ?? this.externalId,
    source: source ?? this.source,
    sourceId: sourceId ?? this.sourceId,
    title: title ?? this.title,
    artist: artist ?? this.artist,
    album: album ?? this.album,
    durationMs: durationMs ?? this.durationMs,
    position: position ?? this.position,
  );
  OnlineReferenceTrackRow copyWithCompanion(
    OnlineReferenceTracksCompanion data,
  ) {
    return OnlineReferenceTrackRow(
      referenceId: data.referenceId.present
          ? data.referenceId.value
          : this.referenceId,
      externalId: data.externalId.present
          ? data.externalId.value
          : this.externalId,
      source: data.source.present ? data.source.value : this.source,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      title: data.title.present ? data.title.value : this.title,
      artist: data.artist.present ? data.artist.value : this.artist,
      album: data.album.present ? data.album.value : this.album,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      position: data.position.present ? data.position.value : this.position,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OnlineReferenceTrackRow(')
          ..write('referenceId: $referenceId, ')
          ..write('externalId: $externalId, ')
          ..write('source: $source, ')
          ..write('sourceId: $sourceId, ')
          ..write('title: $title, ')
          ..write('artist: $artist, ')
          ..write('album: $album, ')
          ..write('durationMs: $durationMs, ')
          ..write('position: $position')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    referenceId,
    externalId,
    source,
    sourceId,
    title,
    artist,
    album,
    durationMs,
    position,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OnlineReferenceTrackRow &&
          other.referenceId == this.referenceId &&
          other.externalId == this.externalId &&
          other.source == this.source &&
          other.sourceId == this.sourceId &&
          other.title == this.title &&
          other.artist == this.artist &&
          other.album == this.album &&
          other.durationMs == this.durationMs &&
          other.position == this.position);
}

class OnlineReferenceTracksCompanion
    extends UpdateCompanion<OnlineReferenceTrackRow> {
  final Value<String> referenceId;
  final Value<String> externalId;
  final Value<String> source;
  final Value<String> sourceId;
  final Value<String> title;
  final Value<String> artist;
  final Value<String> album;
  final Value<int> durationMs;
  final Value<int> position;
  final Value<int> rowid;
  const OnlineReferenceTracksCompanion({
    this.referenceId = const Value.absent(),
    this.externalId = const Value.absent(),
    this.source = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.title = const Value.absent(),
    this.artist = const Value.absent(),
    this.album = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.position = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OnlineReferenceTracksCompanion.insert({
    required String referenceId,
    required String externalId,
    required String source,
    required String sourceId,
    required String title,
    required String artist,
    this.album = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.position = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : referenceId = Value(referenceId),
       externalId = Value(externalId),
       source = Value(source),
       sourceId = Value(sourceId),
       title = Value(title),
       artist = Value(artist);
  static Insertable<OnlineReferenceTrackRow> custom({
    Expression<String>? referenceId,
    Expression<String>? externalId,
    Expression<String>? source,
    Expression<String>? sourceId,
    Expression<String>? title,
    Expression<String>? artist,
    Expression<String>? album,
    Expression<int>? durationMs,
    Expression<int>? position,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (referenceId != null) 'reference_id': referenceId,
      if (externalId != null) 'external_id': externalId,
      if (source != null) 'source': source,
      if (sourceId != null) 'source_id': sourceId,
      if (title != null) 'title': title,
      if (artist != null) 'artist': artist,
      if (album != null) 'album': album,
      if (durationMs != null) 'duration_ms': durationMs,
      if (position != null) 'position': position,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OnlineReferenceTracksCompanion copyWith({
    Value<String>? referenceId,
    Value<String>? externalId,
    Value<String>? source,
    Value<String>? sourceId,
    Value<String>? title,
    Value<String>? artist,
    Value<String>? album,
    Value<int>? durationMs,
    Value<int>? position,
    Value<int>? rowid,
  }) {
    return OnlineReferenceTracksCompanion(
      referenceId: referenceId ?? this.referenceId,
      externalId: externalId ?? this.externalId,
      source: source ?? this.source,
      sourceId: sourceId ?? this.sourceId,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      durationMs: durationMs ?? this.durationMs,
      position: position ?? this.position,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (referenceId.present) {
      map['reference_id'] = Variable<String>(referenceId.value);
    }
    if (externalId.present) {
      map['external_id'] = Variable<String>(externalId.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (artist.present) {
      map['artist'] = Variable<String>(artist.value);
    }
    if (album.present) {
      map['album'] = Variable<String>(album.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OnlineReferenceTracksCompanion(')
          ..write('referenceId: $referenceId, ')
          ..write('externalId: $externalId, ')
          ..write('source: $source, ')
          ..write('sourceId: $sourceId, ')
          ..write('title: $title, ')
          ..write('artist: $artist, ')
          ..write('album: $album, ')
          ..write('durationMs: $durationMs, ')
          ..write('position: $position, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $TracksTable tracks = $TracksTable(this);
  late final $ScanFoldersTable scanFolders = $ScanFoldersTable(this);
  late final $PlaylistsTable playlists = $PlaylistsTable(this);
  late final $PlaylistEntriesTable playlistEntries = $PlaylistEntriesTable(
    this,
  );
  late final $PlayHistoryTable playHistory = $PlayHistoryTable(this);
  late final $EqPresetsTable eqPresets = $EqPresetsTable(this);
  late final $SettingsTable settings = $SettingsTable(this);
  late final $ProfilesTable profiles = $ProfilesTable(this);
  late final $LyricsTable lyrics = $LyricsTable(this);
  late final $PluginsTable plugins = $PluginsTable(this);
  late final $OnlineReferencesTable onlineReferences = $OnlineReferencesTable(
    this,
  );
  late final $OnlineReferenceTracksTable onlineReferenceTracks =
      $OnlineReferenceTracksTable(this);
  late final TrackDao trackDao = TrackDao(this as AppDatabase);
  late final FolderDao folderDao = FolderDao(this as AppDatabase);
  late final PlaylistDao playlistDao = PlaylistDao(this as AppDatabase);
  late final HistoryDao historyDao = HistoryDao(this as AppDatabase);
  late final EqDao eqDao = EqDao(this as AppDatabase);
  late final SettingsDao settingsDao = SettingsDao(this as AppDatabase);
  late final ProfileDao profileDao = ProfileDao(this as AppDatabase);
  late final LyricsDao lyricsDao = LyricsDao(this as AppDatabase);
  late final OnlineSyncDao onlineSyncDao = OnlineSyncDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    tracks,
    scanFolders,
    playlists,
    playlistEntries,
    playHistory,
    eqPresets,
    settings,
    profiles,
    lyrics,
    plugins,
    onlineReferences,
    onlineReferenceTracks,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'playlists',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('playlist_entries', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'tracks',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('playlist_entries', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'tracks',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('play_history', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'tracks',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('lyrics', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$TracksTableCreateCompanionBuilder = TracksCompanion Function({
  Value<int> id,
  required String path,
  required String title,
  Value<String> artist,
  Value<String> album,
  Value<String?> albumArtist,
  Value<String?> genre,
  Value<int?> year,
  Value<int?> trackNumber,
  Value<int?> discNumber,
  Value<int> durationMs,
  Value<int?> bitrate,
  Value<int?> sampleRate,
  Value<String?> format,
  Value<int> fileSize,
  Value<String?> artworkPath,
  Value<String> source,
  Value<String?> externalId,
  Value<double?> replayGainTrackDb,
  Value<double?> replayGainAlbumDb,
  Value<bool> isFavorite,
  Value<int> playCount,
  Value<int> skipCount,
  Value<DateTime?> lastPlayedAt,
  Value<DateTime> addedAt,
  Value<DateTime> updatedAt,
});
typedef $$TracksTableUpdateCompanionBuilder = TracksCompanion Function({
  Value<int> id,
  Value<String> path,
  Value<String> title,
  Value<String> artist,
  Value<String> album,
  Value<String?> albumArtist,
  Value<String?> genre,
  Value<int?> year,
  Value<int?> trackNumber,
  Value<int?> discNumber,
  Value<int> durationMs,
  Value<int?> bitrate,
  Value<int?> sampleRate,
  Value<String?> format,
  Value<int> fileSize,
  Value<String?> artworkPath,
  Value<String> source,
  Value<String?> externalId,
  Value<double?> replayGainTrackDb,
  Value<double?> replayGainAlbumDb,
  Value<bool> isFavorite,
  Value<int> playCount,
  Value<int> skipCount,
  Value<DateTime?> lastPlayedAt,
  Value<DateTime> addedAt,
  Value<DateTime> updatedAt,
});

final class $$TracksTableReferences
    extends BaseReferences<_$AppDatabase, $TracksTable, TrackRow> {
  $$TracksTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$PlaylistEntriesTable, List<PlaylistEntryRow>>
  _playlistEntriesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.playlistEntries,
    aliasName: 'tracks__id__playlist_entries__track_id',
  );

  $$PlaylistEntriesTableProcessedTableManager get playlistEntriesRefs {
    final manager = $$PlaylistEntriesTableTableManager(
      $_db,
      $_db.playlistEntries,
    ).filter((f) => f.trackId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _playlistEntriesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$PlayHistoryTable, List<PlayHistoryRow>>
  _playHistoryRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.playHistory,
    aliasName: 'tracks__id__play_history__track_id',
  );

  $$PlayHistoryTableProcessedTableManager get playHistoryRefs {
    final manager = $$PlayHistoryTableTableManager(
      $_db,
      $_db.playHistory,
    ).filter((f) => f.trackId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_playHistoryRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$LyricsTable, List<LyricRow>> _lyricsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.lyrics,
    aliasName: 'tracks__id__lyrics__track_id',
  );

  $$LyricsTableProcessedTableManager get lyricsRefs {
    final manager = $$LyricsTableTableManager(
      $_db,
      $_db.lyrics,
    ).filter((f) => f.trackId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_lyricsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TracksTableFilterComposer
    extends Composer<_$AppDatabase, $TracksTable> {
  $$TracksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get artist => $composableBuilder(
    column: $table.artist,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get album => $composableBuilder(
    column: $table.album,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get albumArtist => $composableBuilder(
    column: $table.albumArtist,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get genre => $composableBuilder(
    column: $table.genre,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get trackNumber => $composableBuilder(
    column: $table.trackNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get discNumber => $composableBuilder(
    column: $table.discNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bitrate => $composableBuilder(
    column: $table.bitrate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sampleRate => $composableBuilder(
    column: $table.sampleRate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get format => $composableBuilder(
    column: $table.format,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get fileSize => $composableBuilder(
    column: $table.fileSize,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get artworkPath => $composableBuilder(
    column: $table.artworkPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get externalId => $composableBuilder(
    column: $table.externalId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get replayGainTrackDb => $composableBuilder(
    column: $table.replayGainTrackDb,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get replayGainAlbumDb => $composableBuilder(
    column: $table.replayGainAlbumDb,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get playCount => $composableBuilder(
    column: $table.playCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get skipCount => $composableBuilder(
    column: $table.skipCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastPlayedAt => $composableBuilder(
    column: $table.lastPlayedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> playlistEntriesRefs(
    Expression<bool> Function($$PlaylistEntriesTableFilterComposer f) f,
  ) {
    final $$PlaylistEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.playlistEntries,
      getReferencedColumn: (t) => t.trackId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistEntriesTableFilterComposer(
            $db: $db,
            $table: $db.playlistEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> playHistoryRefs(
    Expression<bool> Function($$PlayHistoryTableFilterComposer f) f,
  ) {
    final $$PlayHistoryTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.playHistory,
      getReferencedColumn: (t) => t.trackId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlayHistoryTableFilterComposer(
            $db: $db,
            $table: $db.playHistory,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> lyricsRefs(
    Expression<bool> Function($$LyricsTableFilterComposer f) f,
  ) {
    final $$LyricsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.lyrics,
      getReferencedColumn: (t) => t.trackId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LyricsTableFilterComposer(
            $db: $db,
            $table: $db.lyrics,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TracksTableOrderingComposer
    extends Composer<_$AppDatabase, $TracksTable> {
  $$TracksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get artist => $composableBuilder(
    column: $table.artist,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get album => $composableBuilder(
    column: $table.album,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get albumArtist => $composableBuilder(
    column: $table.albumArtist,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get genre => $composableBuilder(
    column: $table.genre,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get trackNumber => $composableBuilder(
    column: $table.trackNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get discNumber => $composableBuilder(
    column: $table.discNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bitrate => $composableBuilder(
    column: $table.bitrate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sampleRate => $composableBuilder(
    column: $table.sampleRate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get format => $composableBuilder(
    column: $table.format,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fileSize => $composableBuilder(
    column: $table.fileSize,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get artworkPath => $composableBuilder(
    column: $table.artworkPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get externalId => $composableBuilder(
    column: $table.externalId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get replayGainTrackDb => $composableBuilder(
    column: $table.replayGainTrackDb,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get replayGainAlbumDb => $composableBuilder(
    column: $table.replayGainAlbumDb,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get playCount => $composableBuilder(
    column: $table.playCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get skipCount => $composableBuilder(
    column: $table.skipCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastPlayedAt => $composableBuilder(
    column: $table.lastPlayedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TracksTableAnnotationComposer
    extends Composer<_$AppDatabase, $TracksTable> {
  $$TracksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get artist =>
      $composableBuilder(column: $table.artist, builder: (column) => column);

  GeneratedColumn<String> get album =>
      $composableBuilder(column: $table.album, builder: (column) => column);

  GeneratedColumn<String> get albumArtist => $composableBuilder(
    column: $table.albumArtist,
    builder: (column) => column,
  );

  GeneratedColumn<String> get genre =>
      $composableBuilder(column: $table.genre, builder: (column) => column);

  GeneratedColumn<int> get year =>
      $composableBuilder(column: $table.year, builder: (column) => column);

  GeneratedColumn<int> get trackNumber => $composableBuilder(
    column: $table.trackNumber,
    builder: (column) => column,
  );

  GeneratedColumn<int> get discNumber => $composableBuilder(
    column: $table.discNumber,
    builder: (column) => column,
  );

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get bitrate =>
      $composableBuilder(column: $table.bitrate, builder: (column) => column);

  GeneratedColumn<int> get sampleRate => $composableBuilder(
    column: $table.sampleRate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get format =>
      $composableBuilder(column: $table.format, builder: (column) => column);

  GeneratedColumn<int> get fileSize =>
      $composableBuilder(column: $table.fileSize, builder: (column) => column);

  GeneratedColumn<String> get artworkPath => $composableBuilder(
    column: $table.artworkPath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get externalId => $composableBuilder(
    column: $table.externalId,
    builder: (column) => column,
  );

  GeneratedColumn<double> get replayGainTrackDb => $composableBuilder(
    column: $table.replayGainTrackDb,
    builder: (column) => column,
  );

  GeneratedColumn<double> get replayGainAlbumDb => $composableBuilder(
    column: $table.replayGainAlbumDb,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => column,
  );

  GeneratedColumn<int> get playCount =>
      $composableBuilder(column: $table.playCount, builder: (column) => column);

  GeneratedColumn<int> get skipCount =>
      $composableBuilder(column: $table.skipCount, builder: (column) => column);

  GeneratedColumn<DateTime> get lastPlayedAt => $composableBuilder(
    column: $table.lastPlayedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> playlistEntriesRefs<T extends Object>(
    Expression<T> Function($$PlaylistEntriesTableAnnotationComposer a) f,
  ) {
    final $$PlaylistEntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.playlistEntries,
      getReferencedColumn: (t) => t.trackId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistEntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.playlistEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> playHistoryRefs<T extends Object>(
    Expression<T> Function($$PlayHistoryTableAnnotationComposer a) f,
  ) {
    final $$PlayHistoryTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.playHistory,
      getReferencedColumn: (t) => t.trackId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlayHistoryTableAnnotationComposer(
            $db: $db,
            $table: $db.playHistory,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> lyricsRefs<T extends Object>(
    Expression<T> Function($$LyricsTableAnnotationComposer a) f,
  ) {
    final $$LyricsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.lyrics,
      getReferencedColumn: (t) => t.trackId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LyricsTableAnnotationComposer(
            $db: $db,
            $table: $db.lyrics,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TracksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TracksTable,
          TrackRow,
          $$TracksTableFilterComposer,
          $$TracksTableOrderingComposer,
          $$TracksTableAnnotationComposer,
          $$TracksTableCreateCompanionBuilder,
          $$TracksTableUpdateCompanionBuilder,
          (TrackRow, $$TracksTableReferences),
          TrackRow,
          PrefetchHooks Function({
            bool playlistEntriesRefs,
            bool playHistoryRefs,
            bool lyricsRefs,
          })
        > {
  $$TracksTableTableManager(_$AppDatabase db, $TracksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TracksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TracksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TracksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> path = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> artist = const Value.absent(),
                Value<String> album = const Value.absent(),
                Value<String?> albumArtist = const Value.absent(),
                Value<String?> genre = const Value.absent(),
                Value<int?> year = const Value.absent(),
                Value<int?> trackNumber = const Value.absent(),
                Value<int?> discNumber = const Value.absent(),
                Value<int> durationMs = const Value.absent(),
                Value<int?> bitrate = const Value.absent(),
                Value<int?> sampleRate = const Value.absent(),
                Value<String?> format = const Value.absent(),
                Value<int> fileSize = const Value.absent(),
                Value<String?> artworkPath = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String?> externalId = const Value.absent(),
                Value<double?> replayGainTrackDb = const Value.absent(),
                Value<double?> replayGainAlbumDb = const Value.absent(),
                Value<bool> isFavorite = const Value.absent(),
                Value<int> playCount = const Value.absent(),
                Value<int> skipCount = const Value.absent(),
                Value<DateTime?> lastPlayedAt = const Value.absent(),
                Value<DateTime> addedAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => TracksCompanion(
                id: id,
                path: path,
                title: title,
                artist: artist,
                album: album,
                albumArtist: albumArtist,
                genre: genre,
                year: year,
                trackNumber: trackNumber,
                discNumber: discNumber,
                durationMs: durationMs,
                bitrate: bitrate,
                sampleRate: sampleRate,
                format: format,
                fileSize: fileSize,
                artworkPath: artworkPath,
                source: source,
                externalId: externalId,
                replayGainTrackDb: replayGainTrackDb,
                replayGainAlbumDb: replayGainAlbumDb,
                isFavorite: isFavorite,
                playCount: playCount,
                skipCount: skipCount,
                lastPlayedAt: lastPlayedAt,
                addedAt: addedAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String path,
                required String title,
                Value<String> artist = const Value.absent(),
                Value<String> album = const Value.absent(),
                Value<String?> albumArtist = const Value.absent(),
                Value<String?> genre = const Value.absent(),
                Value<int?> year = const Value.absent(),
                Value<int?> trackNumber = const Value.absent(),
                Value<int?> discNumber = const Value.absent(),
                Value<int> durationMs = const Value.absent(),
                Value<int?> bitrate = const Value.absent(),
                Value<int?> sampleRate = const Value.absent(),
                Value<String?> format = const Value.absent(),
                Value<int> fileSize = const Value.absent(),
                Value<String?> artworkPath = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String?> externalId = const Value.absent(),
                Value<double?> replayGainTrackDb = const Value.absent(),
                Value<double?> replayGainAlbumDb = const Value.absent(),
                Value<bool> isFavorite = const Value.absent(),
                Value<int> playCount = const Value.absent(),
                Value<int> skipCount = const Value.absent(),
                Value<DateTime?> lastPlayedAt = const Value.absent(),
                Value<DateTime> addedAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => TracksCompanion.insert(
                id: id,
                path: path,
                title: title,
                artist: artist,
                album: album,
                albumArtist: albumArtist,
                genre: genre,
                year: year,
                trackNumber: trackNumber,
                discNumber: discNumber,
                durationMs: durationMs,
                bitrate: bitrate,
                sampleRate: sampleRate,
                format: format,
                fileSize: fileSize,
                artworkPath: artworkPath,
                source: source,
                externalId: externalId,
                replayGainTrackDb: replayGainTrackDb,
                replayGainAlbumDb: replayGainAlbumDb,
                isFavorite: isFavorite,
                playCount: playCount,
                skipCount: skipCount,
                lastPlayedAt: lastPlayedAt,
                addedAt: addedAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TracksTable, TrackRow>(table),
                  $$TracksTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                playlistEntriesRefs = false,
                playHistoryRefs = false,
                lyricsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (playlistEntriesRefs) db.playlistEntries,
                    if (playHistoryRefs) db.playHistory,
                    if (lyricsRefs) db.lyrics,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (playlistEntriesRefs)
                        await $_getPrefetchedDataByColumns<
                          TrackRow,
                          $TracksTable,
                          PlaylistEntryRow,
                          $PlaylistEntriesTable
                        >(
                          currentTable: table,
                          referencedTable: $$TracksTableReferences
                              ._playlistEntriesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TracksTableReferences(
                                db,
                                table,
                                p0,
                              ).playlistEntriesRefs,
                          currentColumn: 'id',
                          referencedColumn: 'track_id',
                          typedResults: items,
                        ),
                      if (playHistoryRefs)
                        await $_getPrefetchedDataByColumns<
                          TrackRow,
                          $TracksTable,
                          PlayHistoryRow,
                          $PlayHistoryTable
                        >(
                          currentTable: table,
                          referencedTable: $$TracksTableReferences
                              ._playHistoryRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TracksTableReferences(
                                db,
                                table,
                                p0,
                              ).playHistoryRefs,
                          currentColumn: 'id',
                          referencedColumn: 'track_id',
                          typedResults: items,
                        ),
                      if (lyricsRefs)
                        await $_getPrefetchedDataByColumns<
                          TrackRow,
                          $TracksTable,
                          LyricRow,
                          $LyricsTable
                        >(
                          currentTable: table,
                          referencedTable: $$TracksTableReferences
                              ._lyricsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TracksTableReferences(db, table, p0).lyricsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'track_id',
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$TracksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TracksTable,
      TrackRow,
      $$TracksTableFilterComposer,
      $$TracksTableOrderingComposer,
      $$TracksTableAnnotationComposer,
      $$TracksTableCreateCompanionBuilder,
      $$TracksTableUpdateCompanionBuilder,
      (TrackRow, $$TracksTableReferences),
      TrackRow,
      PrefetchHooks Function({
        bool playlistEntriesRefs,
        bool playHistoryRefs,
        bool lyricsRefs,
      })
    >;
typedef $$ScanFoldersTableCreateCompanionBuilder =
    ScanFoldersCompanion Function({
      Value<int> id,
      required String path,
      Value<bool> recursive,
      Value<DateTime> addedAt,
      Value<DateTime?> lastScanAt,
    });
typedef $$ScanFoldersTableUpdateCompanionBuilder =
    ScanFoldersCompanion Function({
      Value<int> id,
      Value<String> path,
      Value<bool> recursive,
      Value<DateTime> addedAt,
      Value<DateTime?> lastScanAt,
    });

class $$ScanFoldersTableFilterComposer
    extends Composer<_$AppDatabase, $ScanFoldersTable> {
  $$ScanFoldersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get recursive => $composableBuilder(
    column: $table.recursive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastScanAt => $composableBuilder(
    column: $table.lastScanAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ScanFoldersTableOrderingComposer
    extends Composer<_$AppDatabase, $ScanFoldersTable> {
  $$ScanFoldersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get recursive => $composableBuilder(
    column: $table.recursive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastScanAt => $composableBuilder(
    column: $table.lastScanAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ScanFoldersTableAnnotationComposer
    extends Composer<_$AppDatabase, $ScanFoldersTable> {
  $$ScanFoldersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<bool> get recursive =>
      $composableBuilder(column: $table.recursive, builder: (column) => column);

  GeneratedColumn<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastScanAt => $composableBuilder(
    column: $table.lastScanAt,
    builder: (column) => column,
  );
}

class $$ScanFoldersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ScanFoldersTable,
          ScanFolderRow,
          $$ScanFoldersTableFilterComposer,
          $$ScanFoldersTableOrderingComposer,
          $$ScanFoldersTableAnnotationComposer,
          $$ScanFoldersTableCreateCompanionBuilder,
          $$ScanFoldersTableUpdateCompanionBuilder,
          (
            ScanFolderRow,
            BaseReferences<_$AppDatabase, $ScanFoldersTable, ScanFolderRow>,
          ),
          ScanFolderRow,
          PrefetchHooks Function()
        > {
  $$ScanFoldersTableTableManager(_$AppDatabase db, $ScanFoldersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ScanFoldersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ScanFoldersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ScanFoldersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> path = const Value.absent(),
                Value<bool> recursive = const Value.absent(),
                Value<DateTime> addedAt = const Value.absent(),
                Value<DateTime?> lastScanAt = const Value.absent(),
              }) => ScanFoldersCompanion(
                id: id,
                path: path,
                recursive: recursive,
                addedAt: addedAt,
                lastScanAt: lastScanAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String path,
                Value<bool> recursive = const Value.absent(),
                Value<DateTime> addedAt = const Value.absent(),
                Value<DateTime?> lastScanAt = const Value.absent(),
              }) => ScanFoldersCompanion.insert(
                id: id,
                path: path,
                recursive: recursive,
                addedAt: addedAt,
                lastScanAt: lastScanAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ScanFoldersTable, ScanFolderRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $ScanFoldersTable,
                    ScanFolderRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ScanFoldersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ScanFoldersTable,
      ScanFolderRow,
      $$ScanFoldersTableFilterComposer,
      $$ScanFoldersTableOrderingComposer,
      $$ScanFoldersTableAnnotationComposer,
      $$ScanFoldersTableCreateCompanionBuilder,
      $$ScanFoldersTableUpdateCompanionBuilder,
      (
        ScanFolderRow,
        BaseReferences<_$AppDatabase, $ScanFoldersTable, ScanFolderRow>,
      ),
      ScanFolderRow,
      PrefetchHooks Function()
    >;
typedef $$PlaylistsTableCreateCompanionBuilder = PlaylistsCompanion Function({
  Value<int> id,
  required String name,
  Value<String?> description,
  Value<bool> isSmart,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
});
typedef $$PlaylistsTableUpdateCompanionBuilder = PlaylistsCompanion Function({
  Value<int> id,
  Value<String> name,
  Value<String?> description,
  Value<bool> isSmart,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
});

final class $$PlaylistsTableReferences
    extends BaseReferences<_$AppDatabase, $PlaylistsTable, PlaylistRow> {
  $$PlaylistsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$PlaylistEntriesTable, List<PlaylistEntryRow>>
  _playlistEntriesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.playlistEntries,
    aliasName: 'playlists__id__playlist_entries__playlist_id',
  );

  $$PlaylistEntriesTableProcessedTableManager get playlistEntriesRefs {
    final manager = $$PlaylistEntriesTableTableManager(
      $_db,
      $_db.playlistEntries,
    ).filter((f) => f.playlistId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _playlistEntriesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$PlaylistsTableFilterComposer
    extends Composer<_$AppDatabase, $PlaylistsTable> {
  $$PlaylistsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isSmart => $composableBuilder(
    column: $table.isSmart,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> playlistEntriesRefs(
    Expression<bool> Function($$PlaylistEntriesTableFilterComposer f) f,
  ) {
    final $$PlaylistEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.playlistEntries,
      getReferencedColumn: (t) => t.playlistId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistEntriesTableFilterComposer(
            $db: $db,
            $table: $db.playlistEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PlaylistsTableOrderingComposer
    extends Composer<_$AppDatabase, $PlaylistsTable> {
  $$PlaylistsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isSmart => $composableBuilder(
    column: $table.isSmart,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PlaylistsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlaylistsTable> {
  $$PlaylistsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isSmart =>
      $composableBuilder(column: $table.isSmart, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> playlistEntriesRefs<T extends Object>(
    Expression<T> Function($$PlaylistEntriesTableAnnotationComposer a) f,
  ) {
    final $$PlaylistEntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.playlistEntries,
      getReferencedColumn: (t) => t.playlistId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistEntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.playlistEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PlaylistsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PlaylistsTable,
          PlaylistRow,
          $$PlaylistsTableFilterComposer,
          $$PlaylistsTableOrderingComposer,
          $$PlaylistsTableAnnotationComposer,
          $$PlaylistsTableCreateCompanionBuilder,
          $$PlaylistsTableUpdateCompanionBuilder,
          (PlaylistRow, $$PlaylistsTableReferences),
          PlaylistRow,
          PrefetchHooks Function({bool playlistEntriesRefs})
        > {
  $$PlaylistsTableTableManager(_$AppDatabase db, $PlaylistsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlaylistsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlaylistsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlaylistsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<bool> isSmart = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => PlaylistsCompanion(
                id: id,
                name: name,
                description: description,
                isSmart: isSmart,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<String?> description = const Value.absent(),
                Value<bool> isSmart = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => PlaylistsCompanion.insert(
                id: id,
                name: name,
                description: description,
                isSmart: isSmart,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PlaylistsTable, PlaylistRow>(table),
                  $$PlaylistsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({playlistEntriesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (playlistEntriesRefs) db.playlistEntries,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (playlistEntriesRefs)
                    await $_getPrefetchedDataByColumns<
                      PlaylistRow,
                      $PlaylistsTable,
                      PlaylistEntryRow,
                      $PlaylistEntriesTable
                    >(
                      currentTable: table,
                      referencedTable: $$PlaylistsTableReferences
                          ._playlistEntriesRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$PlaylistsTableReferences(
                            db,
                            table,
                            p0,
                          ).playlistEntriesRefs,
                      currentColumn: 'id',
                      referencedColumn: 'playlist_id',
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$PlaylistsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PlaylistsTable,
      PlaylistRow,
      $$PlaylistsTableFilterComposer,
      $$PlaylistsTableOrderingComposer,
      $$PlaylistsTableAnnotationComposer,
      $$PlaylistsTableCreateCompanionBuilder,
      $$PlaylistsTableUpdateCompanionBuilder,
      (PlaylistRow, $$PlaylistsTableReferences),
      PlaylistRow,
      PrefetchHooks Function({bool playlistEntriesRefs})
    >;
typedef $$PlaylistEntriesTableCreateCompanionBuilder =
    PlaylistEntriesCompanion Function({
      Value<int> id,
      required int playlistId,
      required int trackId,
      Value<int> position,
    });
typedef $$PlaylistEntriesTableUpdateCompanionBuilder =
    PlaylistEntriesCompanion Function({
      Value<int> id,
      Value<int> playlistId,
      Value<int> trackId,
      Value<int> position,
    });

final class $$PlaylistEntriesTableReferences
    extends
        BaseReferences<_$AppDatabase, $PlaylistEntriesTable, PlaylistEntryRow> {
  $$PlaylistEntriesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $PlaylistsTable _playlistIdTable(_$AppDatabase db) =>
      db.playlists.createAlias('playlist_entries__playlist_id__playlists__id');

  $$PlaylistsTableProcessedTableManager get playlistId {
    final $_column = $_itemColumn<int>('playlist_id')!;

    final manager = $$PlaylistsTableTableManager(
      $_db,
      $_db.playlists,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_playlistIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $TracksTable _trackIdTable(_$AppDatabase db) =>
      db.tracks.createAlias('playlist_entries__track_id__tracks__id');

  $$TracksTableProcessedTableManager get trackId {
    final $_column = $_itemColumn<int>('track_id')!;

    final manager = $$TracksTableTableManager(
      $_db,
      $_db.tracks,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_trackIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PlaylistEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $PlaylistEntriesTable> {
  $$PlaylistEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  $$PlaylistsTableFilterComposer get playlistId {
    final $$PlaylistsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playlistId,
      referencedTable: $db.playlists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistsTableFilterComposer(
            $db: $db,
            $table: $db.playlists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TracksTableFilterComposer get trackId {
    final $$TracksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.tracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TracksTableFilterComposer(
            $db: $db,
            $table: $db.tracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlaylistEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $PlaylistEntriesTable> {
  $$PlaylistEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  $$PlaylistsTableOrderingComposer get playlistId {
    final $$PlaylistsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playlistId,
      referencedTable: $db.playlists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistsTableOrderingComposer(
            $db: $db,
            $table: $db.playlists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TracksTableOrderingComposer get trackId {
    final $$TracksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.tracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TracksTableOrderingComposer(
            $db: $db,
            $table: $db.tracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlaylistEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlaylistEntriesTable> {
  $$PlaylistEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  $$PlaylistsTableAnnotationComposer get playlistId {
    final $$PlaylistsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playlistId,
      referencedTable: $db.playlists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistsTableAnnotationComposer(
            $db: $db,
            $table: $db.playlists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TracksTableAnnotationComposer get trackId {
    final $$TracksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.tracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TracksTableAnnotationComposer(
            $db: $db,
            $table: $db.tracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlaylistEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PlaylistEntriesTable,
          PlaylistEntryRow,
          $$PlaylistEntriesTableFilterComposer,
          $$PlaylistEntriesTableOrderingComposer,
          $$PlaylistEntriesTableAnnotationComposer,
          $$PlaylistEntriesTableCreateCompanionBuilder,
          $$PlaylistEntriesTableUpdateCompanionBuilder,
          (PlaylistEntryRow, $$PlaylistEntriesTableReferences),
          PlaylistEntryRow,
          PrefetchHooks Function({bool playlistId, bool trackId})
        > {
  $$PlaylistEntriesTableTableManager(
    _$AppDatabase db,
    $PlaylistEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlaylistEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlaylistEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlaylistEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> playlistId = const Value.absent(),
                Value<int> trackId = const Value.absent(),
                Value<int> position = const Value.absent(),
              }) => PlaylistEntriesCompanion(
                id: id,
                playlistId: playlistId,
                trackId: trackId,
                position: position,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int playlistId,
                required int trackId,
                Value<int> position = const Value.absent(),
              }) => PlaylistEntriesCompanion.insert(
                id: id,
                playlistId: playlistId,
                trackId: trackId,
                position: position,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PlaylistEntriesTable, PlaylistEntryRow>(table),
                  $$PlaylistEntriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({playlistId = false, trackId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (playlistId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.playlistId,
                        referencedTable: $$PlaylistEntriesTableReferences
                            ._playlistIdTable(db),
                        referencedColumn: $$PlaylistEntriesTableReferences
                            ._playlistIdTable(db)
                            .id,
                      ) as T;
                    }
                    if (trackId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.trackId,
                        referencedTable: $$PlaylistEntriesTableReferences
                            ._trackIdTable(db),
                        referencedColumn: $$PlaylistEntriesTableReferences
                            ._trackIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$PlaylistEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PlaylistEntriesTable,
      PlaylistEntryRow,
      $$PlaylistEntriesTableFilterComposer,
      $$PlaylistEntriesTableOrderingComposer,
      $$PlaylistEntriesTableAnnotationComposer,
      $$PlaylistEntriesTableCreateCompanionBuilder,
      $$PlaylistEntriesTableUpdateCompanionBuilder,
      (PlaylistEntryRow, $$PlaylistEntriesTableReferences),
      PlaylistEntryRow,
      PrefetchHooks Function({bool playlistId, bool trackId})
    >;
typedef $$PlayHistoryTableCreateCompanionBuilder =
    PlayHistoryCompanion Function({
      Value<int> id,
      required int trackId,
      Value<DateTime> startedAt,
      Value<int> msPlayed,
      Value<bool> completed,
    });
typedef $$PlayHistoryTableUpdateCompanionBuilder =
    PlayHistoryCompanion Function({
      Value<int> id,
      Value<int> trackId,
      Value<DateTime> startedAt,
      Value<int> msPlayed,
      Value<bool> completed,
    });

final class $$PlayHistoryTableReferences
    extends BaseReferences<_$AppDatabase, $PlayHistoryTable, PlayHistoryRow> {
  $$PlayHistoryTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $TracksTable _trackIdTable(_$AppDatabase db) =>
      db.tracks.createAlias('play_history__track_id__tracks__id');

  $$TracksTableProcessedTableManager get trackId {
    final $_column = $_itemColumn<int>('track_id')!;

    final manager = $$TracksTableTableManager(
      $_db,
      $_db.tracks,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_trackIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PlayHistoryTableFilterComposer
    extends Composer<_$AppDatabase, $PlayHistoryTable> {
  $$PlayHistoryTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get msPlayed => $composableBuilder(
    column: $table.msPlayed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get completed => $composableBuilder(
    column: $table.completed,
    builder: (column) => ColumnFilters(column),
  );

  $$TracksTableFilterComposer get trackId {
    final $$TracksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.tracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TracksTableFilterComposer(
            $db: $db,
            $table: $db.tracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlayHistoryTableOrderingComposer
    extends Composer<_$AppDatabase, $PlayHistoryTable> {
  $$PlayHistoryTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get msPlayed => $composableBuilder(
    column: $table.msPlayed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get completed => $composableBuilder(
    column: $table.completed,
    builder: (column) => ColumnOrderings(column),
  );

  $$TracksTableOrderingComposer get trackId {
    final $$TracksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.tracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TracksTableOrderingComposer(
            $db: $db,
            $table: $db.tracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlayHistoryTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlayHistoryTable> {
  $$PlayHistoryTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<int> get msPlayed =>
      $composableBuilder(column: $table.msPlayed, builder: (column) => column);

  GeneratedColumn<bool> get completed =>
      $composableBuilder(column: $table.completed, builder: (column) => column);

  $$TracksTableAnnotationComposer get trackId {
    final $$TracksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.tracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TracksTableAnnotationComposer(
            $db: $db,
            $table: $db.tracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlayHistoryTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PlayHistoryTable,
          PlayHistoryRow,
          $$PlayHistoryTableFilterComposer,
          $$PlayHistoryTableOrderingComposer,
          $$PlayHistoryTableAnnotationComposer,
          $$PlayHistoryTableCreateCompanionBuilder,
          $$PlayHistoryTableUpdateCompanionBuilder,
          (PlayHistoryRow, $$PlayHistoryTableReferences),
          PlayHistoryRow,
          PrefetchHooks Function({bool trackId})
        > {
  $$PlayHistoryTableTableManager(_$AppDatabase db, $PlayHistoryTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlayHistoryTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlayHistoryTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlayHistoryTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> trackId = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<int> msPlayed = const Value.absent(),
                Value<bool> completed = const Value.absent(),
              }) => PlayHistoryCompanion(
                id: id,
                trackId: trackId,
                startedAt: startedAt,
                msPlayed: msPlayed,
                completed: completed,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int trackId,
                Value<DateTime> startedAt = const Value.absent(),
                Value<int> msPlayed = const Value.absent(),
                Value<bool> completed = const Value.absent(),
              }) => PlayHistoryCompanion.insert(
                id: id,
                trackId: trackId,
                startedAt: startedAt,
                msPlayed: msPlayed,
                completed: completed,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PlayHistoryTable, PlayHistoryRow>(table),
                  $$PlayHistoryTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({trackId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (trackId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.trackId,
                        referencedTable: $$PlayHistoryTableReferences
                            ._trackIdTable(db),
                        referencedColumn: $$PlayHistoryTableReferences
                            ._trackIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$PlayHistoryTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PlayHistoryTable,
      PlayHistoryRow,
      $$PlayHistoryTableFilterComposer,
      $$PlayHistoryTableOrderingComposer,
      $$PlayHistoryTableAnnotationComposer,
      $$PlayHistoryTableCreateCompanionBuilder,
      $$PlayHistoryTableUpdateCompanionBuilder,
      (PlayHistoryRow, $$PlayHistoryTableReferences),
      PlayHistoryRow,
      PrefetchHooks Function({bool trackId})
    >;
typedef $$EqPresetsTableCreateCompanionBuilder = EqPresetsCompanion Function({
  Value<int> id,
  required String name,
  Value<bool> isBuiltIn,
  required String bandsJson,
  Value<double> preampDb,
  Value<String?> configJson,
  Value<DateTime> createdAt,
});
typedef $$EqPresetsTableUpdateCompanionBuilder = EqPresetsCompanion Function({
  Value<int> id,
  Value<String> name,
  Value<bool> isBuiltIn,
  Value<String> bandsJson,
  Value<double> preampDb,
  Value<String?> configJson,
  Value<DateTime> createdAt,
});

class $$EqPresetsTableFilterComposer
    extends Composer<_$AppDatabase, $EqPresetsTable> {
  $$EqPresetsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isBuiltIn => $composableBuilder(
    column: $table.isBuiltIn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bandsJson => $composableBuilder(
    column: $table.bandsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get preampDb => $composableBuilder(
    column: $table.preampDb,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get configJson => $composableBuilder(
    column: $table.configJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EqPresetsTableOrderingComposer
    extends Composer<_$AppDatabase, $EqPresetsTable> {
  $$EqPresetsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isBuiltIn => $composableBuilder(
    column: $table.isBuiltIn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bandsJson => $composableBuilder(
    column: $table.bandsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get preampDb => $composableBuilder(
    column: $table.preampDb,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get configJson => $composableBuilder(
    column: $table.configJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EqPresetsTableAnnotationComposer
    extends Composer<_$AppDatabase, $EqPresetsTable> {
  $$EqPresetsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<bool> get isBuiltIn =>
      $composableBuilder(column: $table.isBuiltIn, builder: (column) => column);

  GeneratedColumn<String> get bandsJson =>
      $composableBuilder(column: $table.bandsJson, builder: (column) => column);

  GeneratedColumn<double> get preampDb =>
      $composableBuilder(column: $table.preampDb, builder: (column) => column);

  GeneratedColumn<String> get configJson => $composableBuilder(
    column: $table.configJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$EqPresetsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EqPresetsTable,
          EqPresetRow,
          $$EqPresetsTableFilterComposer,
          $$EqPresetsTableOrderingComposer,
          $$EqPresetsTableAnnotationComposer,
          $$EqPresetsTableCreateCompanionBuilder,
          $$EqPresetsTableUpdateCompanionBuilder,
          (
            EqPresetRow,
            BaseReferences<_$AppDatabase, $EqPresetsTable, EqPresetRow>,
          ),
          EqPresetRow,
          PrefetchHooks Function()
        > {
  $$EqPresetsTableTableManager(_$AppDatabase db, $EqPresetsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EqPresetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EqPresetsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EqPresetsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<bool> isBuiltIn = const Value.absent(),
                Value<String> bandsJson = const Value.absent(),
                Value<double> preampDb = const Value.absent(),
                Value<String?> configJson = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => EqPresetsCompanion(
                id: id,
                name: name,
                isBuiltIn: isBuiltIn,
                bandsJson: bandsJson,
                preampDb: preampDb,
                configJson: configJson,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<bool> isBuiltIn = const Value.absent(),
                required String bandsJson,
                Value<double> preampDb = const Value.absent(),
                Value<String?> configJson = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => EqPresetsCompanion.insert(
                id: id,
                name: name,
                isBuiltIn: isBuiltIn,
                bandsJson: bandsJson,
                preampDb: preampDb,
                configJson: configJson,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$EqPresetsTable, EqPresetRow>(table),
                  BaseReferences<_$AppDatabase, $EqPresetsTable, EqPresetRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EqPresetsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EqPresetsTable,
      EqPresetRow,
      $$EqPresetsTableFilterComposer,
      $$EqPresetsTableOrderingComposer,
      $$EqPresetsTableAnnotationComposer,
      $$EqPresetsTableCreateCompanionBuilder,
      $$EqPresetsTableUpdateCompanionBuilder,
      (
        EqPresetRow,
        BaseReferences<_$AppDatabase, $EqPresetsTable, EqPresetRow>,
      ),
      EqPresetRow,
      PrefetchHooks Function()
    >;
typedef $$SettingsTableCreateCompanionBuilder = SettingsCompanion Function({
  Value<String> scope,
  required String key,
  required String value,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});
typedef $$SettingsTableUpdateCompanionBuilder = SettingsCompanion Function({
  Value<String> scope,
  Value<String> key,
  Value<String> value,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$SettingsTableFilterComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get scope =>
      $composableBuilder(column: $table.scope, builder: (column) => column);

  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$SettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SettingsTable,
          SettingRow,
          $$SettingsTableFilterComposer,
          $$SettingsTableOrderingComposer,
          $$SettingsTableAnnotationComposer,
          $$SettingsTableCreateCompanionBuilder,
          $$SettingsTableUpdateCompanionBuilder,
          (
            SettingRow,
            BaseReferences<_$AppDatabase, $SettingsTable, SettingRow>,
          ),
          SettingRow,
          PrefetchHooks Function()
        > {
  $$SettingsTableTableManager(_$AppDatabase db, $SettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> scope = const Value.absent(),
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SettingsCompanion(
                scope: scope,
                key: key,
                value: value,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String> scope = const Value.absent(),
                required String key,
                required String value,
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SettingsCompanion.insert(
                scope: scope,
                key: key,
                value: value,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SettingsTable, SettingRow>(table),
                  BaseReferences<_$AppDatabase, $SettingsTable, SettingRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SettingsTable,
      SettingRow,
      $$SettingsTableFilterComposer,
      $$SettingsTableOrderingComposer,
      $$SettingsTableAnnotationComposer,
      $$SettingsTableCreateCompanionBuilder,
      $$SettingsTableUpdateCompanionBuilder,
      (SettingRow, BaseReferences<_$AppDatabase, $SettingsTable, SettingRow>),
      SettingRow,
      PrefetchHooks Function()
    >;
typedef $$ProfilesTableCreateCompanionBuilder = ProfilesCompanion Function({
  Value<int> id,
  required String name,
  Value<bool> isActive,
  Value<DateTime> createdAt,
});
typedef $$ProfilesTableUpdateCompanionBuilder = ProfilesCompanion Function({
  Value<int> id,
  Value<String> name,
  Value<bool> isActive,
  Value<DateTime> createdAt,
});

class $$ProfilesTableFilterComposer
    extends Composer<_$AppDatabase, $ProfilesTable> {
  $$ProfilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ProfilesTableOrderingComposer
    extends Composer<_$AppDatabase, $ProfilesTable> {
  $$ProfilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ProfilesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProfilesTable> {
  $$ProfilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$ProfilesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ProfilesTable,
          ProfileRow,
          $$ProfilesTableFilterComposer,
          $$ProfilesTableOrderingComposer,
          $$ProfilesTableAnnotationComposer,
          $$ProfilesTableCreateCompanionBuilder,
          $$ProfilesTableUpdateCompanionBuilder,
          (
            ProfileRow,
            BaseReferences<_$AppDatabase, $ProfilesTable, ProfileRow>,
          ),
          ProfileRow,
          PrefetchHooks Function()
        > {
  $$ProfilesTableTableManager(_$AppDatabase db, $ProfilesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProfilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProfilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProfilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => ProfilesCompanion(
                id: id,
                name: name,
                isActive: isActive,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<bool> isActive = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => ProfilesCompanion.insert(
                id: id,
                name: name,
                isActive: isActive,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ProfilesTable, ProfileRow>(table),
                  BaseReferences<_$AppDatabase, $ProfilesTable, ProfileRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ProfilesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ProfilesTable,
      ProfileRow,
      $$ProfilesTableFilterComposer,
      $$ProfilesTableOrderingComposer,
      $$ProfilesTableAnnotationComposer,
      $$ProfilesTableCreateCompanionBuilder,
      $$ProfilesTableUpdateCompanionBuilder,
      (ProfileRow, BaseReferences<_$AppDatabase, $ProfilesTable, ProfileRow>),
      ProfileRow,
      PrefetchHooks Function()
    >;
typedef $$LyricsTableCreateCompanionBuilder = LyricsCompanion Function({
  Value<int> trackId,
  required String content,
  Value<bool> synced,
  Value<String> source,
  Value<DateTime> fetchedAt,
});
typedef $$LyricsTableUpdateCompanionBuilder = LyricsCompanion Function({
  Value<int> trackId,
  Value<String> content,
  Value<bool> synced,
  Value<String> source,
  Value<DateTime> fetchedAt,
});

final class $$LyricsTableReferences
    extends BaseReferences<_$AppDatabase, $LyricsTable, LyricRow> {
  $$LyricsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $TracksTable _trackIdTable(_$AppDatabase db) =>
      db.tracks.createAlias('lyrics__track_id__tracks__id');

  $$TracksTableProcessedTableManager get trackId {
    final $_column = $_itemColumn<int>('track_id')!;

    final manager = $$TracksTableTableManager(
      $_db,
      $_db.tracks,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_trackIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$LyricsTableFilterComposer
    extends Composer<_$AppDatabase, $LyricsTable> {
  $$LyricsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get synced => $composableBuilder(
    column: $table.synced,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$TracksTableFilterComposer get trackId {
    final $$TracksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.tracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TracksTableFilterComposer(
            $db: $db,
            $table: $db.tracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LyricsTableOrderingComposer
    extends Composer<_$AppDatabase, $LyricsTable> {
  $$LyricsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get synced => $composableBuilder(
    column: $table.synced,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$TracksTableOrderingComposer get trackId {
    final $$TracksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.tracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TracksTableOrderingComposer(
            $db: $db,
            $table: $db.tracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LyricsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LyricsTable> {
  $$LyricsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<bool> get synced =>
      $composableBuilder(column: $table.synced, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<DateTime> get fetchedAt =>
      $composableBuilder(column: $table.fetchedAt, builder: (column) => column);

  $$TracksTableAnnotationComposer get trackId {
    final $$TracksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.tracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TracksTableAnnotationComposer(
            $db: $db,
            $table: $db.tracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LyricsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LyricsTable,
          LyricRow,
          $$LyricsTableFilterComposer,
          $$LyricsTableOrderingComposer,
          $$LyricsTableAnnotationComposer,
          $$LyricsTableCreateCompanionBuilder,
          $$LyricsTableUpdateCompanionBuilder,
          (LyricRow, $$LyricsTableReferences),
          LyricRow,
          PrefetchHooks Function({bool trackId})
        > {
  $$LyricsTableTableManager(_$AppDatabase db, $LyricsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LyricsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LyricsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LyricsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> trackId = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<bool> synced = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<DateTime> fetchedAt = const Value.absent(),
              }) => LyricsCompanion(
                trackId: trackId,
                content: content,
                synced: synced,
                source: source,
                fetchedAt: fetchedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> trackId = const Value.absent(),
                required String content,
                Value<bool> synced = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<DateTime> fetchedAt = const Value.absent(),
              }) => LyricsCompanion.insert(
                trackId: trackId,
                content: content,
                synced: synced,
                source: source,
                fetchedAt: fetchedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LyricsTable, LyricRow>(table),
                  $$LyricsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({trackId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (trackId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.trackId,
                        referencedTable: $$LyricsTableReferences._trackIdTable(
                          db,
                        ),
                        referencedColumn: $$LyricsTableReferences
                            ._trackIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$LyricsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LyricsTable,
      LyricRow,
      $$LyricsTableFilterComposer,
      $$LyricsTableOrderingComposer,
      $$LyricsTableAnnotationComposer,
      $$LyricsTableCreateCompanionBuilder,
      $$LyricsTableUpdateCompanionBuilder,
      (LyricRow, $$LyricsTableReferences),
      LyricRow,
      PrefetchHooks Function({bool trackId})
    >;
typedef $$PluginsTableCreateCompanionBuilder = PluginsCompanion Function({
  Value<int> id,
  required String name,
  required String version,
  Value<bool> enabled,
  Value<String?> configJson,
  Value<DateTime> installedAt,
});
typedef $$PluginsTableUpdateCompanionBuilder = PluginsCompanion Function({
  Value<int> id,
  Value<String> name,
  Value<String> version,
  Value<bool> enabled,
  Value<String?> configJson,
  Value<DateTime> installedAt,
});

class $$PluginsTableFilterComposer
    extends Composer<_$AppDatabase, $PluginsTable> {
  $$PluginsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get configJson => $composableBuilder(
    column: $table.configJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get installedAt => $composableBuilder(
    column: $table.installedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PluginsTableOrderingComposer
    extends Composer<_$AppDatabase, $PluginsTable> {
  $$PluginsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get configJson => $composableBuilder(
    column: $table.configJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get installedAt => $composableBuilder(
    column: $table.installedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PluginsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PluginsTable> {
  $$PluginsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);

  GeneratedColumn<String> get configJson => $composableBuilder(
    column: $table.configJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get installedAt => $composableBuilder(
    column: $table.installedAt,
    builder: (column) => column,
  );
}

class $$PluginsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PluginsTable,
          PluginRow,
          $$PluginsTableFilterComposer,
          $$PluginsTableOrderingComposer,
          $$PluginsTableAnnotationComposer,
          $$PluginsTableCreateCompanionBuilder,
          $$PluginsTableUpdateCompanionBuilder,
          (PluginRow, BaseReferences<_$AppDatabase, $PluginsTable, PluginRow>),
          PluginRow,
          PrefetchHooks Function()
        > {
  $$PluginsTableTableManager(_$AppDatabase db, $PluginsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PluginsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PluginsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PluginsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> version = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<String?> configJson = const Value.absent(),
                Value<DateTime> installedAt = const Value.absent(),
              }) => PluginsCompanion(
                id: id,
                name: name,
                version: version,
                enabled: enabled,
                configJson: configJson,
                installedAt: installedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required String version,
                Value<bool> enabled = const Value.absent(),
                Value<String?> configJson = const Value.absent(),
                Value<DateTime> installedAt = const Value.absent(),
              }) => PluginsCompanion.insert(
                id: id,
                name: name,
                version: version,
                enabled: enabled,
                configJson: configJson,
                installedAt: installedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PluginsTable, PluginRow>(table),
                  BaseReferences<_$AppDatabase, $PluginsTable, PluginRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PluginsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PluginsTable,
      PluginRow,
      $$PluginsTableFilterComposer,
      $$PluginsTableOrderingComposer,
      $$PluginsTableAnnotationComposer,
      $$PluginsTableCreateCompanionBuilder,
      $$PluginsTableUpdateCompanionBuilder,
      (PluginRow, BaseReferences<_$AppDatabase, $PluginsTable, PluginRow>),
      PluginRow,
      PrefetchHooks Function()
    >;
typedef $$OnlineReferencesTableCreateCompanionBuilder =
    OnlineReferencesCompanion Function({
      required String externalId,
      required String source,
      required String kind,
      required String nativeId,
      required String title,
      Value<String> subtitle,
      Value<String?> artworkPath,
      Value<String?> permalink,
      Value<int> trackCount,
      Value<String?> continuation,
      Value<bool> hasMore,
      Value<DateTime?> syncedAt,
      Value<DateTime?> lastSuccessfulSyncAt,
      Value<String?> lastError,
      Value<bool> isFavorite,
      Value<int> playCount,
      Value<int> rowid,
    });
typedef $$OnlineReferencesTableUpdateCompanionBuilder =
    OnlineReferencesCompanion Function({
      Value<String> externalId,
      Value<String> source,
      Value<String> kind,
      Value<String> nativeId,
      Value<String> title,
      Value<String> subtitle,
      Value<String?> artworkPath,
      Value<String?> permalink,
      Value<int> trackCount,
      Value<String?> continuation,
      Value<bool> hasMore,
      Value<DateTime?> syncedAt,
      Value<DateTime?> lastSuccessfulSyncAt,
      Value<String?> lastError,
      Value<bool> isFavorite,
      Value<int> playCount,
      Value<int> rowid,
    });

class $$OnlineReferencesTableFilterComposer
    extends Composer<_$AppDatabase, $OnlineReferencesTable> {
  $$OnlineReferencesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get externalId => $composableBuilder(
    column: $table.externalId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nativeId => $composableBuilder(
    column: $table.nativeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subtitle => $composableBuilder(
    column: $table.subtitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get artworkPath => $composableBuilder(
    column: $table.artworkPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get permalink => $composableBuilder(
    column: $table.permalink,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get trackCount => $composableBuilder(
    column: $table.trackCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get continuation => $composableBuilder(
    column: $table.continuation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get hasMore => $composableBuilder(
    column: $table.hasMore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSuccessfulSyncAt => $composableBuilder(
    column: $table.lastSuccessfulSyncAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get playCount => $composableBuilder(
    column: $table.playCount,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OnlineReferencesTableOrderingComposer
    extends Composer<_$AppDatabase, $OnlineReferencesTable> {
  $$OnlineReferencesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get externalId => $composableBuilder(
    column: $table.externalId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nativeId => $composableBuilder(
    column: $table.nativeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subtitle => $composableBuilder(
    column: $table.subtitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get artworkPath => $composableBuilder(
    column: $table.artworkPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get permalink => $composableBuilder(
    column: $table.permalink,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get trackCount => $composableBuilder(
    column: $table.trackCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get continuation => $composableBuilder(
    column: $table.continuation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get hasMore => $composableBuilder(
    column: $table.hasMore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get syncedAt => $composableBuilder(
    column: $table.syncedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSuccessfulSyncAt => $composableBuilder(
    column: $table.lastSuccessfulSyncAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get playCount => $composableBuilder(
    column: $table.playCount,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OnlineReferencesTableAnnotationComposer
    extends Composer<_$AppDatabase, $OnlineReferencesTable> {
  $$OnlineReferencesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get externalId => $composableBuilder(
    column: $table.externalId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get nativeId =>
      $composableBuilder(column: $table.nativeId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get subtitle =>
      $composableBuilder(column: $table.subtitle, builder: (column) => column);

  GeneratedColumn<String> get artworkPath => $composableBuilder(
    column: $table.artworkPath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get permalink =>
      $composableBuilder(column: $table.permalink, builder: (column) => column);

  GeneratedColumn<int> get trackCount => $composableBuilder(
    column: $table.trackCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get continuation => $composableBuilder(
    column: $table.continuation,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get hasMore =>
      $composableBuilder(column: $table.hasMore, builder: (column) => column);

  GeneratedColumn<DateTime> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastSuccessfulSyncAt => $composableBuilder(
    column: $table.lastSuccessfulSyncAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => column,
  );

  GeneratedColumn<int> get playCount =>
      $composableBuilder(column: $table.playCount, builder: (column) => column);
}

class $$OnlineReferencesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OnlineReferencesTable,
          OnlineReferenceRow,
          $$OnlineReferencesTableFilterComposer,
          $$OnlineReferencesTableOrderingComposer,
          $$OnlineReferencesTableAnnotationComposer,
          $$OnlineReferencesTableCreateCompanionBuilder,
          $$OnlineReferencesTableUpdateCompanionBuilder,
          (
            OnlineReferenceRow,
            BaseReferences<
              _$AppDatabase,
              $OnlineReferencesTable,
              OnlineReferenceRow
            >,
          ),
          OnlineReferenceRow,
          PrefetchHooks Function()
        > {
  $$OnlineReferencesTableTableManager(
    _$AppDatabase db,
    $OnlineReferencesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OnlineReferencesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OnlineReferencesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OnlineReferencesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> externalId = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> nativeId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> subtitle = const Value.absent(),
                Value<String?> artworkPath = const Value.absent(),
                Value<String?> permalink = const Value.absent(),
                Value<int> trackCount = const Value.absent(),
                Value<String?> continuation = const Value.absent(),
                Value<bool> hasMore = const Value.absent(),
                Value<DateTime?> syncedAt = const Value.absent(),
                Value<DateTime?> lastSuccessfulSyncAt = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<bool> isFavorite = const Value.absent(),
                Value<int> playCount = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OnlineReferencesCompanion(
                externalId: externalId,
                source: source,
                kind: kind,
                nativeId: nativeId,
                title: title,
                subtitle: subtitle,
                artworkPath: artworkPath,
                permalink: permalink,
                trackCount: trackCount,
                continuation: continuation,
                hasMore: hasMore,
                syncedAt: syncedAt,
                lastSuccessfulSyncAt: lastSuccessfulSyncAt,
                lastError: lastError,
                isFavorite: isFavorite,
                playCount: playCount,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String externalId,
                required String source,
                required String kind,
                required String nativeId,
                required String title,
                Value<String> subtitle = const Value.absent(),
                Value<String?> artworkPath = const Value.absent(),
                Value<String?> permalink = const Value.absent(),
                Value<int> trackCount = const Value.absent(),
                Value<String?> continuation = const Value.absent(),
                Value<bool> hasMore = const Value.absent(),
                Value<DateTime?> syncedAt = const Value.absent(),
                Value<DateTime?> lastSuccessfulSyncAt = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<bool> isFavorite = const Value.absent(),
                Value<int> playCount = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OnlineReferencesCompanion.insert(
                externalId: externalId,
                source: source,
                kind: kind,
                nativeId: nativeId,
                title: title,
                subtitle: subtitle,
                artworkPath: artworkPath,
                permalink: permalink,
                trackCount: trackCount,
                continuation: continuation,
                hasMore: hasMore,
                syncedAt: syncedAt,
                lastSuccessfulSyncAt: lastSuccessfulSyncAt,
                lastError: lastError,
                isFavorite: isFavorite,
                playCount: playCount,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$OnlineReferencesTable, OnlineReferenceRow>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $OnlineReferencesTable,
                    OnlineReferenceRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OnlineReferencesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OnlineReferencesTable,
      OnlineReferenceRow,
      $$OnlineReferencesTableFilterComposer,
      $$OnlineReferencesTableOrderingComposer,
      $$OnlineReferencesTableAnnotationComposer,
      $$OnlineReferencesTableCreateCompanionBuilder,
      $$OnlineReferencesTableUpdateCompanionBuilder,
      (
        OnlineReferenceRow,
        BaseReferences<
          _$AppDatabase,
          $OnlineReferencesTable,
          OnlineReferenceRow
        >,
      ),
      OnlineReferenceRow,
      PrefetchHooks Function()
    >;
typedef $$OnlineReferenceTracksTableCreateCompanionBuilder =
    OnlineReferenceTracksCompanion Function({
      required String referenceId,
      required String externalId,
      required String source,
      required String sourceId,
      required String title,
      required String artist,
      Value<String> album,
      Value<int> durationMs,
      Value<int> position,
      Value<int> rowid,
    });
typedef $$OnlineReferenceTracksTableUpdateCompanionBuilder =
    OnlineReferenceTracksCompanion Function({
      Value<String> referenceId,
      Value<String> externalId,
      Value<String> source,
      Value<String> sourceId,
      Value<String> title,
      Value<String> artist,
      Value<String> album,
      Value<int> durationMs,
      Value<int> position,
      Value<int> rowid,
    });

class $$OnlineReferenceTracksTableFilterComposer
    extends Composer<_$AppDatabase, $OnlineReferenceTracksTable> {
  $$OnlineReferenceTracksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get referenceId => $composableBuilder(
    column: $table.referenceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get externalId => $composableBuilder(
    column: $table.externalId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get artist => $composableBuilder(
    column: $table.artist,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get album => $composableBuilder(
    column: $table.album,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OnlineReferenceTracksTableOrderingComposer
    extends Composer<_$AppDatabase, $OnlineReferenceTracksTable> {
  $$OnlineReferenceTracksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get referenceId => $composableBuilder(
    column: $table.referenceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get externalId => $composableBuilder(
    column: $table.externalId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get artist => $composableBuilder(
    column: $table.artist,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get album => $composableBuilder(
    column: $table.album,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OnlineReferenceTracksTableAnnotationComposer
    extends Composer<_$AppDatabase, $OnlineReferenceTracksTable> {
  $$OnlineReferenceTracksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get referenceId => $composableBuilder(
    column: $table.referenceId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get externalId => $composableBuilder(
    column: $table.externalId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get sourceId =>
      $composableBuilder(column: $table.sourceId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get artist =>
      $composableBuilder(column: $table.artist, builder: (column) => column);

  GeneratedColumn<String> get album =>
      $composableBuilder(column: $table.album, builder: (column) => column);

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);
}

class $$OnlineReferenceTracksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OnlineReferenceTracksTable,
          OnlineReferenceTrackRow,
          $$OnlineReferenceTracksTableFilterComposer,
          $$OnlineReferenceTracksTableOrderingComposer,
          $$OnlineReferenceTracksTableAnnotationComposer,
          $$OnlineReferenceTracksTableCreateCompanionBuilder,
          $$OnlineReferenceTracksTableUpdateCompanionBuilder,
          (
            OnlineReferenceTrackRow,
            BaseReferences<
              _$AppDatabase,
              $OnlineReferenceTracksTable,
              OnlineReferenceTrackRow
            >,
          ),
          OnlineReferenceTrackRow,
          PrefetchHooks Function()
        > {
  $$OnlineReferenceTracksTableTableManager(
    _$AppDatabase db,
    $OnlineReferenceTracksTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OnlineReferenceTracksTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$OnlineReferenceTracksTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$OnlineReferenceTracksTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> referenceId = const Value.absent(),
                Value<String> externalId = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String> sourceId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> artist = const Value.absent(),
                Value<String> album = const Value.absent(),
                Value<int> durationMs = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OnlineReferenceTracksCompanion(
                referenceId: referenceId,
                externalId: externalId,
                source: source,
                sourceId: sourceId,
                title: title,
                artist: artist,
                album: album,
                durationMs: durationMs,
                position: position,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String referenceId,
                required String externalId,
                required String source,
                required String sourceId,
                required String title,
                required String artist,
                Value<String> album = const Value.absent(),
                Value<int> durationMs = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OnlineReferenceTracksCompanion.insert(
                referenceId: referenceId,
                externalId: externalId,
                source: source,
                sourceId: sourceId,
                title: title,
                artist: artist,
                album: album,
                durationMs: durationMs,
                position: position,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $OnlineReferenceTracksTable,
                    OnlineReferenceTrackRow
                  >(table),
                  BaseReferences<
                    _$AppDatabase,
                    $OnlineReferenceTracksTable,
                    OnlineReferenceTrackRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OnlineReferenceTracksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OnlineReferenceTracksTable,
      OnlineReferenceTrackRow,
      $$OnlineReferenceTracksTableFilterComposer,
      $$OnlineReferenceTracksTableOrderingComposer,
      $$OnlineReferenceTracksTableAnnotationComposer,
      $$OnlineReferenceTracksTableCreateCompanionBuilder,
      $$OnlineReferenceTracksTableUpdateCompanionBuilder,
      (
        OnlineReferenceTrackRow,
        BaseReferences<
          _$AppDatabase,
          $OnlineReferenceTracksTable,
          OnlineReferenceTrackRow
        >,
      ),
      OnlineReferenceTrackRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$TracksTableTableManager get tracks =>
      $$TracksTableTableManager(_db, _db.tracks);
  $$ScanFoldersTableTableManager get scanFolders =>
      $$ScanFoldersTableTableManager(_db, _db.scanFolders);
  $$PlaylistsTableTableManager get playlists =>
      $$PlaylistsTableTableManager(_db, _db.playlists);
  $$PlaylistEntriesTableTableManager get playlistEntries =>
      $$PlaylistEntriesTableTableManager(_db, _db.playlistEntries);
  $$PlayHistoryTableTableManager get playHistory =>
      $$PlayHistoryTableTableManager(_db, _db.playHistory);
  $$EqPresetsTableTableManager get eqPresets =>
      $$EqPresetsTableTableManager(_db, _db.eqPresets);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
  $$ProfilesTableTableManager get profiles =>
      $$ProfilesTableTableManager(_db, _db.profiles);
  $$LyricsTableTableManager get lyrics =>
      $$LyricsTableTableManager(_db, _db.lyrics);
  $$PluginsTableTableManager get plugins =>
      $$PluginsTableTableManager(_db, _db.plugins);
  $$OnlineReferencesTableTableManager get onlineReferences =>
      $$OnlineReferencesTableTableManager(_db, _db.onlineReferences);
  $$OnlineReferenceTracksTableTableManager get onlineReferenceTracks =>
      $$OnlineReferenceTracksTableTableManager(_db, _db.onlineReferenceTracks);
}

mixin _$TrackDaoMixin on DatabaseAccessor<AppDatabase> {
  $TracksTable get tracks => attachedDatabase.tracks;
  TrackDaoManager get managers => TrackDaoManager(this);
}

class TrackDaoManager {
  final _$TrackDaoMixin _db;
  TrackDaoManager(this._db);
  $$TracksTableTableManager get tracks =>
      $$TracksTableTableManager(_db.attachedDatabase, _db.tracks);
}

mixin _$FolderDaoMixin on DatabaseAccessor<AppDatabase> {
  $ScanFoldersTable get scanFolders => attachedDatabase.scanFolders;
  FolderDaoManager get managers => FolderDaoManager(this);
}

class FolderDaoManager {
  final _$FolderDaoMixin _db;
  FolderDaoManager(this._db);
  $$ScanFoldersTableTableManager get scanFolders =>
      $$ScanFoldersTableTableManager(_db.attachedDatabase, _db.scanFolders);
}

mixin _$PlaylistDaoMixin on DatabaseAccessor<AppDatabase> {
  $PlaylistsTable get playlists => attachedDatabase.playlists;
  $TracksTable get tracks => attachedDatabase.tracks;
  $PlaylistEntriesTable get playlistEntries => attachedDatabase.playlistEntries;
  PlaylistDaoManager get managers => PlaylistDaoManager(this);
}

class PlaylistDaoManager {
  final _$PlaylistDaoMixin _db;
  PlaylistDaoManager(this._db);
  $$PlaylistsTableTableManager get playlists =>
      $$PlaylistsTableTableManager(_db.attachedDatabase, _db.playlists);
  $$TracksTableTableManager get tracks =>
      $$TracksTableTableManager(_db.attachedDatabase, _db.tracks);
  $$PlaylistEntriesTableTableManager get playlistEntries =>
      $$PlaylistEntriesTableTableManager(
        _db.attachedDatabase,
        _db.playlistEntries,
      );
}

mixin _$HistoryDaoMixin on DatabaseAccessor<AppDatabase> {
  $TracksTable get tracks => attachedDatabase.tracks;
  $PlayHistoryTable get playHistory => attachedDatabase.playHistory;
  HistoryDaoManager get managers => HistoryDaoManager(this);
}

class HistoryDaoManager {
  final _$HistoryDaoMixin _db;
  HistoryDaoManager(this._db);
  $$TracksTableTableManager get tracks =>
      $$TracksTableTableManager(_db.attachedDatabase, _db.tracks);
  $$PlayHistoryTableTableManager get playHistory =>
      $$PlayHistoryTableTableManager(_db.attachedDatabase, _db.playHistory);
}

mixin _$EqDaoMixin on DatabaseAccessor<AppDatabase> {
  $EqPresetsTable get eqPresets => attachedDatabase.eqPresets;
  EqDaoManager get managers => EqDaoManager(this);
}

class EqDaoManager {
  final _$EqDaoMixin _db;
  EqDaoManager(this._db);
  $$EqPresetsTableTableManager get eqPresets =>
      $$EqPresetsTableTableManager(_db.attachedDatabase, _db.eqPresets);
}

mixin _$SettingsDaoMixin on DatabaseAccessor<AppDatabase> {
  $SettingsTable get settings => attachedDatabase.settings;
  SettingsDaoManager get managers => SettingsDaoManager(this);
}

class SettingsDaoManager {
  final _$SettingsDaoMixin _db;
  SettingsDaoManager(this._db);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db.attachedDatabase, _db.settings);
}

mixin _$ProfileDaoMixin on DatabaseAccessor<AppDatabase> {
  $ProfilesTable get profiles => attachedDatabase.profiles;
  ProfileDaoManager get managers => ProfileDaoManager(this);
}

class ProfileDaoManager {
  final _$ProfileDaoMixin _db;
  ProfileDaoManager(this._db);
  $$ProfilesTableTableManager get profiles =>
      $$ProfilesTableTableManager(_db.attachedDatabase, _db.profiles);
}

mixin _$LyricsDaoMixin on DatabaseAccessor<AppDatabase> {
  $TracksTable get tracks => attachedDatabase.tracks;
  $LyricsTable get lyrics => attachedDatabase.lyrics;
  LyricsDaoManager get managers => LyricsDaoManager(this);
}

class LyricsDaoManager {
  final _$LyricsDaoMixin _db;
  LyricsDaoManager(this._db);
  $$TracksTableTableManager get tracks =>
      $$TracksTableTableManager(_db.attachedDatabase, _db.tracks);
  $$LyricsTableTableManager get lyrics =>
      $$LyricsTableTableManager(_db.attachedDatabase, _db.lyrics);
}

mixin _$OnlineSyncDaoMixin on DatabaseAccessor<AppDatabase> {
  $OnlineReferencesTable get onlineReferences =>
      attachedDatabase.onlineReferences;
  $OnlineReferenceTracksTable get onlineReferenceTracks =>
      attachedDatabase.onlineReferenceTracks;
  OnlineSyncDaoManager get managers => OnlineSyncDaoManager(this);
}

class OnlineSyncDaoManager {
  final _$OnlineSyncDaoMixin _db;
  OnlineSyncDaoManager(this._db);
  $$OnlineReferencesTableTableManager get onlineReferences =>
      $$OnlineReferencesTableTableManager(
        _db.attachedDatabase,
        _db.onlineReferences,
      );
  $$OnlineReferenceTracksTableTableManager get onlineReferenceTracks =>
      $$OnlineReferenceTracksTableTableManager(
        _db.attachedDatabase,
        _db.onlineReferenceTracks,
      );
}
