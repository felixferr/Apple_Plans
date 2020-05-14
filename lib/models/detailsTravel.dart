import 'package:dio/dio.dart';
import 'package:geoloc/credentials.dart';

class DetailsTravel {
  Dio dio = new Dio();

  Future<String> getDistance(currentLocationLat, currentLocationLong,
      _destinationLatitude, _destinationLongitude) async {
    String url =
        "https://maps.googleapis.com/maps/api/distancematrix/json?units=metric&origins=${currentLocationLat},${currentLocationLong}&destinations=${_destinationLatitude},${_destinationLongitude}&language=fr-FR&key=$kGoogleApiKey";
    Response response = await dio.get(url);

    return response.data["rows"][0]["elements"][0]["distance"]["text"];
  }

  Future<String> getDuration(currentLocationLat, currentLocationLong,
      _destinationLatitude, _destinationLongitude) async {
    String url =
        "https://maps.googleapis.com/maps/api/distancematrix/json?units=metric&origins=${currentLocationLat},${currentLocationLong}&destinations=${_destinationLatitude},${_destinationLongitude}&language=fr-FR&key=$kGoogleApiKey";
    Response response = await dio.get(url);

    return response.data["rows"][0]["elements"][0]["duration"]["text"];
  }
}
