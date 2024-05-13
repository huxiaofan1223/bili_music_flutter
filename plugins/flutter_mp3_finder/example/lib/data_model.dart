class DataModel {
  List<Mp3Model> mp3Files;

  DataModel(this.mp3Files);

  // DataModel.fromJson(Map<String, dynamic> json) {
  //   if (json['Mp3Files'] != null) {
  //     mp3Files = List<Mp3Model>();
  //     json['Mp3Files'].forEach((v) {
  //       mp3Files.add(Mp3Model.fromJson(v));
  //     });
  //   }
  // }
}

class Mp3Model {
  final String path;
  final String displayName;
  final String album;
  final String albumImage;
  final String artist;
  final String dateAdded;
  final String size;
  final String duration;

  Mp3Model(
      {required this.path,
      required this.displayName,
      required this.album,
      required this.albumImage,
      required this.artist,
      required this.dateAdded,
      required this.size,
      required this.duration});

  factory Mp3Model.fromJson(Map<String, dynamic> json) => Mp3Model(
        path: json["path"],
        displayName: json["displayName"],
        album: json["album"],
        albumImage: json["albumImage"],
        artist: json["artist"],
        dateAdded: json["dateAdded"],
        size: json["size"],
        duration: json["duration"],
      );
  Map<String, dynamic> toJson() => {
        "path": this.path,
        "displayName": this.displayName,
        "album": this.album,
        "shortName": this.albumImage,
        "artist": this.artist,
        "dateAdded": this.dateAdded,
        "size": this.size,
        "duration": this.duration,
      };
}
