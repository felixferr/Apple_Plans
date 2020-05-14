import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:geoloc/models/detailsTravel.dart';
import 'credentials.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:flutter_google_places/flutter_google_places.dart';
import 'package:google_maps_webservice/places.dart' as places;
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:geoloc/credentials.dart';
import 'package:auto_size_text/auto_size_text.dart';

class Map extends StatefulWidget {
  @override
  _MapState createState() => _MapState();
}

class _MapState extends State<Map> {
  Marker marker;
  GoogleMapController _controller;
  PanelController _pc = new PanelController();
  double _panelHeightOpen;
  double _panelHeightClosed = 95.0;
  double _panelHeightItineraire = 220;
  double _destinationLatitude;
  double _destinationLongitude;
  bool checkIfItineraire = false;
  bool onTapSearch = false;
  bool checkIfSelectItineraire = false;
  bool checkIfOk = false;
  String searchAddress;
  String retrieveFormatAdress;
  String distanceTravel;
  String durationTravel;
  String addressStreet;

  Set<Polyline> _polylines = {};
  List<LatLng> polylineCoordinates = [];
  PolylinePoints polylinePoints = PolylinePoints();
  DetailsTravel detailsTravel = DetailsTravel();
  BitmapDescriptor _markerIcon;
  Set<Marker> _markers = HashSet<Marker>();

  void initState() {
    _getUserLocation();
    super.initState();
  }

  // INITIAL POSITION CAMERA

  static final CameraPosition initialLocation = CameraPosition(
    target: LatLng(48.8566969, 2.3514616),
    zoom: 14.4746,
  );

  // GET CURRENT USER LOCATION

  _getUserLocation() async {
    setState(() {
      checkIfItineraire = false;
    });
    Uint8List imageData = await _setNavigationIcon();
    updateIcon(imageData);

    geo.Position position = await geo.Geolocator()
        .getCurrentPosition(desiredAccuracy: geo.LocationAccuracy.high);

    _controller.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(
        target: LatLng(position.latitude, position.longitude), zoom: 17.0)));
  }

  //TOGGLE MAP STYLE

  void setMapStyle() async {
    String style = await DefaultAssetBundle.of(context)
        .loadString('assets/map_style_dark.json');
    _controller.setMapStyle(style);
    if (checkIfOk) {
      _controller.setMapStyle(null);
    } else {
      _controller.setMapStyle(style);
    }
  }

  // SEARCHBAR

  Widget searchBar() {
    return checkIfOk
        ? SizedBox.shrink()
        : checkIfItineraire
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

                      places.Prediction p = await PlacesAutocomplete.show(
                          context: context,
                          apiKey: kGoogleApiKey,
                          language: "fr",
                          mode: Mode.overlay,
                          logo: Container(height: 0),
                          components: [
                            places.Component(places.Component.country, "fr")
                          ]);
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
                      prefixIcon: Icon(
                        Icons.search,
                        size: 30.0,
                      ),
                      filled: true,
                    ),
                  ),
                ),
              );
  }

  Widget iconLocation() {
    return checkIfOk
        ? SizedBox.shrink()
        : Positioned(
            left: MediaQuery.of(context).size.width * 0.85,
            top: MediaQuery.of(context).size.height * 0.14,
            child: Container(
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.black54),
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

  // SLIDING PANEL

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
                height: MediaQuery.of(context).size.height * 0.006,
              ),
              Align(
                alignment: Alignment.center,
                child: Container(
                  height: MediaQuery.of(context).size.height * 0.006,
                  width: MediaQuery.of(context).size.width * 0.1,
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: Color.fromRGBO(188, 188, 188, 0.5)),
                ),
              ),
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.006,
              ),
              searchBar(),
              detailsLocation(),
              viewTravel(),
              SizedBox(
                height: 24,
              ),
            ],
          ),
        ));
  }

  // LIST ADDRESS

  Future<Null> displayPrediction(places.Prediction p) async {
    if (p != null) {
      _pc.close();
      setState(() {
        onTapSearch = false;
        checkIfItineraire = true;
      });

      searchAddress = p.description;
      addressStreet = searchAddress.substring(0, searchAddress.indexOf(','));
      retrieveFormatAdress = searchAddress.substring(
          searchAddress.indexOf(',') + 2, searchAddress.length);
      // display marker.png to the address
      _setMarkerIcon();
      // navigate to the address
      searchAndNavigate();
    } else {
      _pc.close();
      setState(() {
        onTapSearch = false;
      });
    }
  }

  // SET MARKER ICON LOCATION TO THE ADDRESS SELECTED ON THE SEARCHBAR

  void _setMarkerIcon() async {
    _markerIcon = await BitmapDescriptor.fromAssetImage(
        ImageConfiguration(), 'assets/marker.png');
  }

  BitmapDescriptor navigationIcon;
  Future<Uint8List> _setNavigationIcon() async {
    ByteData byteData =
        await DefaultAssetBundle.of(context).load("assets/navigation-icon.png");
    return byteData.buffer.asUint8List();
  }

  Future updateIcon(Uint8List imageData) async {
    geo.Position position = await geo.Geolocator()
        .getCurrentPosition(desiredAccuracy: geo.LocationAccuracy.high);
    this.setState(() {
      marker = Marker(
          markerId: MarkerId("currentLocation"),
          position: LatLng(position.latitude, position.longitude),
          rotation: position.heading,
          draggable: false,
          zIndex: 2,
          flat: true,
          anchor: Offset(0.5, 0.5),
          icon: BitmapDescriptor.fromBytes(imageData));
    });
  }

  // DISPLAY VIEW BETWEEN USER LOCATION AND THE ADDRESS

  void searchAndNavigate() {
    geo.Geolocator().placemarkFromAddress(searchAddress).then((value) async {
      var latLng =
          LatLng(value[0].position.latitude, value[0].position.longitude);
      geo.Position position = await geo.Geolocator()
          .getCurrentPosition(desiredAccuracy: geo.LocationAccuracy.high);

      distanceTravel = await detailsTravel.getDistance(
          position.latitude,
          position.longitude,
          value[0].position.latitude,
          value[0].position.longitude);

      durationTravel = await detailsTravel.getDuration(
          position.latitude,
          position.longitude,
          value[0].position.latitude,
          value[0].position.longitude);

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

  // DETAILS TRAVEL

  Widget detailsLocation() {
    return checkIfOk
        ? SizedBox.shrink()
        : checkIfItineraire
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
                                      fontSize:
                                          MediaQuery.of(context).size.height *
                                              0.022),
                                )
                              : SizedBox.shrink(),
                          SizedBox(
                            width: MediaQuery.of(context).size.width * 0.01,
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              SizedBox(
                                width: 240,
                                child: AutoSizeText(
                                  addressStreet,
                                  maxLines: 2,
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize:
                                          MediaQuery.of(context).size.height *
                                              0.02),
                                ),
                              ),
                              checkIfSelectItineraire
                                  ? SizedBox.shrink()
                                  : Text(
                                      distanceTravel ?? '',
                                      style: TextStyle(color: Colors.white),
                                    )
                            ],
                          )
                        ],
                      ),
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(100),
                          color: Color.fromRGBO(0, 0, 0, 0.2),
                        ),
                        child: IconButton(
                          icon: Icon(Icons.close),
                          color: Colors.grey,
                          onPressed: () {
                            setState(() {
                              checkIfItineraire = false;
                              checkIfSelectItineraire = false;
                              _getUserLocation();
                              polylineCoordinates.clear();
                              _polylines.clear();
                              _markers.clear();
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  checkIfSelectItineraire
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'De',
                              style:
                                  TextStyle(color: Colors.white, fontSize: 20),
                            ),
                            SizedBox(
                              width: MediaQuery.of(context).size.width * 0.015,
                            ),
                            Padding(
                              padding: const EdgeInsets.only(top: 1.0),
                              child: Text(
                                'Ma position',
                                style: TextStyle(
                                    color: Colors.blue[700], fontSize: 18),
                              ),
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
                                  fontSize: MediaQuery.of(context).size.height *
                                      0.022),
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
                                      fontSize:
                                          MediaQuery.of(context).size.height *
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
                                onPressed: () async {
                                  setMapStyle();
                                  _getUserLocation();
                                  checkIfOk = true;
                                },
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
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                Text(
                                  'Itinéraire',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16),
                                ),
                                Text(
                                  durationTravel ?? '',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ],
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
                          crossAxisAlignment: CrossAxisAlignment.start,
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
                            Text(addressStreet,
                                style: TextStyle(color: Colors.white)),
                            Text(retrieveFormatAdress,
                                style: TextStyle(color: Colors.white)),
                          ],
                        ),
                ],
              )
            : SizedBox.shrink();
  }

  // SET ROUTE WITH POLYLINES

  setPolylines() async {
    geo.Position position = await geo.Geolocator()
        .getCurrentPosition(desiredAccuracy: geo.LocationAccuracy.high);
    List<PointLatLng> result = await polylinePoints?.getRouteBetweenCoordinates(
        kGoogleApiKeyDirections,
        position.latitude,
        position.longitude,
        _destinationLatitude,
        _destinationLongitude);

    distanceTravel = await detailsTravel.getDistance(position.latitude,
        position.longitude, _destinationLatitude, _destinationLongitude);
    durationTravel = await detailsTravel.getDuration(position.latitude,
        position.longitude, _destinationLatitude, _destinationLongitude);

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
    LatLng userLocation = LatLng(position.latitude, position.longitude);
    LatLng addressSearch = LatLng(_destinationLatitude, _destinationLongitude);

    _controller.moveCamera(CameraUpdate.newLatLngBounds(
        LatLngBounds(
            southwest: position.latitude >= _destinationLatitude
                ? addressSearch
                : userLocation,
            northeast: position.latitude >= _destinationLatitude
                ? userLocation
                : addressSearch),
        150));
  }

  // DETAILS VIEW TRAVEL

  Widget viewTravel() {
    return checkIfOk
        ? Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(durationTravel,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: MediaQuery.of(context).size.height * 0.020)),
              Text(
                distanceTravel,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: MediaQuery.of(context).size.height * 0.020),
              ),
              Container(
                width: MediaQuery.of(context).size.width * 0.18,
                height: MediaQuery.of(context).size.height * 0.06,
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: Colors.red[600]),
                child: FlatButton(
                  child: Text(
                    'Fin',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: MediaQuery.of(context).size.height * 0.020),
                  ),
                  onPressed: () {
                    setMapStyle();
                    _getUserLocation();
                    checkIfOk = false;
                    checkIfItineraire = false;
                    checkIfSelectItineraire = false;
                    polylineCoordinates.clear();
                    _polylines.clear();
                    _markers.clear();
                  },
                ),
              )
            ],
          )
        : SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    _panelHeightOpen = MediaQuery.of(context).size.height * 0.925;
    return Scaffold(
      appBar: checkIfOk
          ? AppBar(
              title: Text('Démarrez'),
              backgroundColor: Colors.black87,
            )
          : null,
      body: Stack(
        children: <Widget>[
          GoogleMap(
            mapType: MapType.normal,
            initialCameraPosition: initialLocation,
            markers:
                checkIfOk ? Set.of((marker != null) ? [marker] : []) : _markers,
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
            color: checkIfOk ? Colors.white : Color.fromRGBO(17, 17, 17, 0.9),
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
