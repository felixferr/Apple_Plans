import 'dart:convert';

import 'package:geoloc/credentials.dart';
import 'package:http/http.dart' as http;

class DetailsTravel {
  final String hour;
  final String distance;

  DetailsTravel({this.hour, this.distance});

  Future<String> getDetails(currentLocationLat, currentLocationLong,
      _destinationLatitude, _destinationLongitude) async {
    String url =
        "https://maps.googleapis.com/maps/api/distancematrix/json?units=imperial&origins=${currentLocationLat},${currentLocationLong}&destinations=${_destinationLatitude},${_destinationLongitude}&key=$kGoogleApiKey";
    http.Response response = await http.get(url);
    Map values = jsonDecode(response.body);
    String distance = values["rows"][0]["elements"][0]["distance"]["text"];
    print(values);
    return distance;
  }
}
