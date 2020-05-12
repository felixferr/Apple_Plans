import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geoloc/models/detailsTravel.dart';
import 'dart:async';
import 'dart:collection';

import 'dart:typed_data';
import 'credentials.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:geolocator/geolocator.dart' as l;
import 'package:sliding_up_panel/sliding_up_panel.dart';

import 'package:flutter_google_places/flutter_google_places.dart';
import 'package:google_maps_webservice/places.dart' as G;
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

import 'package:geoloc/credentials.dart';
import 'package:dio/dio.dart';

class Map extends StatefulWidget {
  @override
  _MapState createState() => _MapState();
}

class _MapState extends State<Map> {
  StreamSubscription _locationSubscription;
  Marker marker;
  Circle circle;
  GoogleMapController _controller;
  PanelController _pc = new PanelController();
  final addressController = TextEditingController();
  double _panelHeightOpen;
  double _panelHeightClosed = 95.0;
  double _panelHeightItineraire = 220;
  String searchAddress;
  bool checkIfItineraire = false;
  bool onTapSearch = false;
  String retrieveFormatAdress;
  LatLng south;
  LatLng north;
  Dio dio = new Dio();
  String distanceTravel;
  String durationTravel;

  double _destinationLatitude;
  double _destinationLongitude;

  Set<Polyline> _polylines = {};
  List<LatLng> polylineCoordinates = [];
  PolylinePoints polylinePoints = PolylinePoints();
  DetailsTravel detailsTravel = DetailsTravel();

  void initState() {
    _getUserLocation();
    super.initState();
  }

  @override
  void dispose() {
    if (_locationSubscription != null) {
      _locationSubscription.cancel();
    }
    super.dispose();
  }

  static final CameraPosition initialLocation = CameraPosition(
    target: LatLng(48.8566969, 2.3514616),
    zoom: 14.4746,
  );

  // Get currentlocation

  _getUserLocation() async {
    setState(() {
      checkIfItineraire = false;
    });

    l.Position position = await l.Geolocator()
        .getCurrentPosition(desiredAccuracy: l.LocationAccuracy.high);
    List<l.Placemark> placemark = await l.Geolocator()
        .placemarkFromCoordinates(position.latitude, position.longitude);
    _controller.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(
        target: LatLng(position.latitude, position.longitude), zoom: 17.0)));
  }

  //Map Style

  void setMapStyle() async {
    String style = await DefaultAssetBundle.of(context)
        .loadString('assets/map_style.json');
    _controller.setMapStyle(style);
  }

  // SearchBar

  Widget searchBar() {
    return checkIfItineraire
        ? SizedBox.shrink()
        : Container(
            height: MediaQuery.of(context).size.height * 0.06,
            width: double.infinity,
            child: Center(
              child: TextField(
                onTap: () async {
                  setState(() {
                    onTapSearch = true;
                  });

                  await _pc.open();

                  G.Prediction p = await PlacesAutocomplete.show(
                      context: context,
                      apiKey: kGoogleApiKey,
                      language: "fr",
                      mode: Mode.overlay,
                      logo: Container(height: 0),
                      components: [G.Component(G.Component.country, "fr")]);
                  displayPrediction(p);
                },
                decoration: InputDecoration(
                  fillColor: Colors.grey[400],
                  contentPadding: EdgeInsets.symmetric(vertical: 15.0),
                  border: new OutlineInputBorder(
                    borderRadius: const BorderRadius.all(
                      const Radius.circular(10.0),
                    ),
                  ),
                  hintText: 'Rechercher lieu ou adresse',
                  prefixIcon: IconButton(
                    icon: Icon(
                      Icons.search,
                      size: 30.0,
                    ),
                    onPressed: () {},
                  ),
                  filled: true,
                ),
              ),
            ),
          );
  }

  //iconLocation

  Widget iconLocation() {
    return Positioned(
      left: 360,
      top: 50,
      child: Container(
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10), color: Colors.black54),
        child: IconButton(
          icon: Icon(
            Icons.navigation,
            color: Colors.white,
          ),
          onPressed: () => _getUserLocation(),
        ),
      ),
    );
  }

// Slide panel

  Widget _panel(ScrollController sc) {
    return MediaQuery.removePadding(
        context: context,
        removeTop: true,
        child: Padding(
          padding: const EdgeInsets.only(left: 16, right: 16),
          child: ListView(
            controller: sc,
            children: <Widget>[
              SizedBox(
                height: 12.0,
              ),
              searchBar(),
              detailsLocation(),
              SizedBox(
                height: 24,
              ),
            ],
          ),
        ));
  }

  // if tap on address => Naviguate

  Future<Null> displayPrediction(G.Prediction p) async {
    if (p != null) {
      _pc.close();
      setState(() {
        onTapSearch = false;
        checkIfItineraire = true;
      });

      searchAddress = p.description;
      retrieveFormatAdress =
          searchAddress.substring(0, searchAddress.indexOf(','));

      _setMarkerIcon();
      await searchAndNavigate();

      //  var address = await Geocoder.local.findAddressesFromQuery(p.description);

    } else {
      _pc.close();
      setState(() {
        onTapSearch = false;
      });
    }
  }

  // set marker location to select adresse by the searchbar

  BitmapDescriptor _markerIcon;
  Set<Marker> _markers = HashSet<Marker>();

  void _setMarkerIcon() async {
    _markerIcon = await BitmapDescriptor.fromAssetImage(
        ImageConfiguration(), 'assets/marker.png');
  }

  void searchAndNavigate() {
    l.Geolocator().placemarkFromAddress(searchAddress).then((value) async {
      var latLng =
          LatLng(value[0].position.latitude, value[0].position.longitude);

      setState(() {
        _markers.add(
          Marker(
              markerId: MarkerId(latLng.toString()),
              position: LatLng(
                  value[0].position.latitude, value[0].position.longitude),
              icon: _markerIcon),
        );
      });

      _controller.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(
          target:
              LatLng(value[0].position.latitude, value[0].position.longitude),
          zoom: 17.0)));

      _destinationLatitude = value[0].position.latitude;
      _destinationLongitude = value[0].position.longitude;
    });
  }

  Future<Uint8List> getMarkerSearchLocation() async {
    ByteData byteData =
        await DefaultAssetBundle.of(context).load("assets/marker.png");
    return byteData.buffer.asUint8List();
  }

  // display view itineraire on sliding panel
  bool checkIfSelectItineraire = false;

  Widget detailsLocation() {
    return checkIfItineraire
        ? Column(
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      checkIfSelectItineraire
                          ? Text(
                              'Vers',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: MediaQuery.of(context).size.height *
                                      0.022),
                            )
                          : SizedBox.shrink(),
                      SizedBox(
                        width: MediaQuery.of(context).size.width * 0.01,
                      ),
                      Text(
                        retrieveFormatAdress,
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize:
                                MediaQuery.of(context).size.height * 0.02),
                      )
                    ],
                  ),
                  RawMaterialButton(
                    shape: CircleBorder(),
                    fillColor: Color.fromRGBO(0, 0, 0, 0.2),
                    elevation: 1.0,
                    child: Icon(
                      Icons.close,
                      color: Colors.grey,
                    ),
                    onPressed: () {
                      setState(() {
                        checkIfItineraire = false;
                        checkIfSelectItineraire = false;

                        polylineCoordinates.clear();
                        _polylines.clear();
                        _markers.clear();
                      });
                    },
                  )
                ],
              ),
              checkIfSelectItineraire
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'De',
                          style: TextStyle(color: Colors.white, fontSize: 20),
                        ),
                        SizedBox(
                          width: MediaQuery.of(context).size.width * 0.015,
                        ),
                        Text(
                          'Ma position',
                          style:
                              TextStyle(color: Colors.blue[500], fontSize: 20),
                        )
                      ],
                    )
                  : SizedBox.shrink(),
              checkIfSelectItineraire
                  ? Divider(
                      color: Colors.grey,
                    )
                  : SizedBox.shrink(),
              SizedBox(
                height: 20,
              ),
              checkIfSelectItineraire
                  ? Row(
                      children: <Widget>[
                        Text(
                          durationTravel,
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize:
                                  MediaQuery.of(context).size.height * 0.022),
                        ),
                      ],
                    )
                  : SizedBox.shrink(),
              checkIfSelectItineraire
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Text(
                              distanceTravel,
                              style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: MediaQuery.of(context).size.height *
                                      0.018),
                            ),
                          ],
                        ),
                        Container(
                          width: MediaQuery.of(context).size.width * 0.15,
                          height: MediaQuery.of(context).size.height * 0.06,
                          decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: Colors.green[600]),
                          child: FlatButton(
                            child: Text(
                              'OK',
                              style: TextStyle(color: Colors.white),
                            ),
                            onPressed: () => _getUserLocation(),
                          ),
                        )
                      ],
                    )
                  : SizedBox.shrink(),
              checkIfSelectItineraire
                  ? SizedBox.shrink()
                  : Container(
                      width: MediaQuery.of(context).size.width * 0.95,
                      height: MediaQuery.of(context).size.height * 0.06,
                      child: FlatButton(
                        color: Color.fromARGB(255, 40, 122, 198),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6.0),
                        ),
                        child: Text(
                          'Itinéraire',
                          style: TextStyle(color: Colors.white),
                        ),
                        onPressed: () async {
                          checkIfSelectItineraire = true;
                          await setPolylines();
                        },
                      ),
                    ),
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.018,
              ),
              checkIfSelectItineraire
                  ? SizedBox.shrink()
                  : Column(
                      children: <Widget>[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: <Widget>[
                            Container(
                              child: Text(
                                'Adresse',
                                style: TextStyle(color: Colors.white70),
                              ),
                            ),
                          ],
                        ),
                        Text(searchAddress,
                            style: TextStyle(color: Colors.white)),
                      ],
                    ),
            ],
          )
        : SizedBox.shrink();
  }

  bool checkIfPlDl = false;

  setPolylines() async {
    l.Position position = await l.Geolocator()
        .getCurrentPosition(desiredAccuracy: l.LocationAccuracy.high);
    List<PointLatLng> result = await polylinePoints?.getRouteBetweenCoordinates(
        kGoogleApiKeyDirections,
        position.latitude,
        position.longitude,
        _destinationLatitude,
        _destinationLongitude);

    await getDistance(position.latitude, position.longitude,
        _destinationLatitude, _destinationLongitude);
    await getDuration(position.latitude, position.longitude,
        _destinationLatitude, _destinationLongitude);

    if (result.isNotEmpty) {
      // loop through all PointLatLng points and convert them
      // to a list of LatLng, required by the Polyline
      result.forEach((PointLatLng point) {
        polylineCoordinates.add(LatLng(point.latitude, point.longitude));
      });
    }

    setState(() {
      // create a Polyline instance
      // with an id, an RGB color and the list of LatLng pairs
      Polyline polyline = Polyline(
          polylineId: PolylineId("poly"),
          color: Color.fromARGB(255, 40, 122, 198),
          points: polylineCoordinates);

      // add the constructed polyline as a set of points
      // to the polyline set, which will eventually
      // end up showing up on the map
      _polylines.add(polyline);
    });
    LatLng south = LatLng(position.latitude, position.longitude);
    LatLng north = LatLng(_destinationLatitude, _destinationLongitude);
    print(south.latitude);
    print(north.latitude);

    if (position.latitude >= _destinationLatitude) {
      checkIfPlDl = true;
    } else {
      checkIfPlDl = false;
    }
    print(checkIfPlDl);
    _controller.moveCamera(CameraUpdate.newLatLngBounds(
        LatLngBounds(
            southwest: checkIfPlDl ? north : south,
            northeast: checkIfPlDl ? south : north),
        120));
  }

  Future<String> getDistance(currentLocationLat, currentLocationLong,
      _destinationLatitude, _destinationLongitude) async {
    String url =
        "https://maps.googleapis.com/maps/api/distancematrix/json?units=metric&origins=${currentLocationLat},${currentLocationLong}&destinations=${_destinationLatitude},${_destinationLongitude}&language=fr-FR&key=$kGoogleApiKey";
    Response response = await dio.get(url);

    String distance =
        response.data["rows"][0]["elements"][0]["distance"]["text"];
    distanceTravel = distance;
  }

  Future<String> getDuration(currentLocationLat, currentLocationLong,
      _destinationLatitude, _destinationLongitude) async {
    String url =
        "https://maps.googleapis.com/maps/api/distancematrix/json?units=metric&origins=${currentLocationLat},${currentLocationLong}&destinations=${_destinationLatitude},${_destinationLongitude}&language=fr-FR&key=$kGoogleApiKey";
    Response response = await dio.get(url);

    String duration =
        response.data["rows"][0]["elements"][0]["duration"]["text"];
    durationTravel = duration;
    print(response);
  }

  @override
  Widget build(BuildContext context) {
    _panelHeightOpen = MediaQuery.of(context).size.height * 0.925;
    return Scaffold(
      body: Stack(
        children: <Widget>[
          GoogleMap(
            mapType: MapType.normal,
            initialCameraPosition: initialLocation,
            markers: _markers,
            circles: Set.of((circle != null) ? [circle] : []),
            myLocationButtonEnabled: false,
            myLocationEnabled: true,
            polylines: _polylines,
            onMapCreated: (GoogleMapController controller) {
              _controller = controller;
              setMapStyle();
            },
          ),
          iconLocation(),
          SlidingUpPanel(
            maxHeight: _panelHeightOpen,
            minHeight:
                checkIfItineraire ? _panelHeightItineraire : _panelHeightClosed,
            parallaxEnabled: true,
            parallaxOffset: .5,
            controller: _pc,
            color: Color.fromRGBO(84, 85, 85, 0.8),
            panelBuilder: (sc) => onTapSearch ? SizedBox.shrink() : _panel(sc),
            borderRadius: BorderRadius.only(
                topLeft: Radius.circular(18.0),
                topRight: Radius.circular(18.0)),
          )
        ],
      ),
    );
  }
}
