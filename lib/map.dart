import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:collection';

import 'dart:typed_data';
import 'constants.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:geolocator/geolocator.dart' as l;
import 'package:sliding_up_panel/sliding_up_panel.dart';

import 'package:flutter_google_places/flutter_google_places.dart';
import 'package:google_maps_webservice/places.dart' as G;

class Map extends StatefulWidget {
  @override
  _MapState createState() => _MapState();
}

class _MapState extends State<Map> {
  StreamSubscription _locationSubscription;
  Location _locationTracker = Location();
  Marker marker;
  Circle circle;
  GoogleMapController _controller;
  PanelController _pc = new PanelController();
  static LatLng _initialPosition;

  void initState() {
    _getUserLocation();
    super.initState();
  }

  static final CameraPosition initialLocation = CameraPosition(
    target: LatLng(48.8566969, 2.3514616),
    zoom: 14.4746,
  );
  // Marker Current Location

  // Get location
  _getUserLocation() async {
    l.Position position = await l.Geolocator()
        .getCurrentPosition(desiredAccuracy: l.LocationAccuracy.high);
    List<l.Placemark> placemark = await l.Geolocator()
        .placemarkFromCoordinates(position.latitude, position.longitude);
    _controller.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(
        target: LatLng(position.latitude, position.longitude), zoom: 17.0)));
  }

  final addressController = TextEditingController();

  //Map Style

  void setMapStyle() async {
    String style = await DefaultAssetBundle.of(context)
        .loadString('assets/map_style.json');
    _controller.setMapStyle(style);
  }

  @override
  void dispose() {
    if (_locationSubscription != null) {
      _locationSubscription.cancel();
    }
    super.dispose();
  }

  Widget searchBar() {
    return Container(
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
               // apiKey: kGoogleApiKey,
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

  double _panelHeightOpen;
  double _panelHeightClosed = 95.0;

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
              SizedBox(
                height: 24,
              ),
            ],
          ),
        ));
  }

  String searchAddress;

  Future<Null> displayPrediction(G.Prediction p) async {
    if (p != null) {
      _pc.close();
      setState(() {
        onTapSearch = false;
      });

      searchAddress = p.description;
      _setMarkerIcon();
      await searchAndNavigate();
      print(searchAddress);

      //  var address = await Geocoder.local.findAddressesFromQuery(p.description);

    } else {
      _pc.close();
      setState(() {
        onTapSearch = false;
      });
    }
  }

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
              infoWindow: InfoWindow(
                title: "San Francsico",
                snippet: "An Interesting city",
              ),
              icon: _markerIcon),
        );
      });

      _controller.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(
          target:
              LatLng(value[0].position.latitude, value[0].position.longitude),
          zoom: 17.0)));
    });
  }

  Future<Uint8List> getMarkerSearchLocation() async {
    ByteData byteData =
        await DefaultAssetBundle.of(context).load("assets/marker.png");
    return byteData.buffer.asUint8List();
  }

  bool onTapSearch = false;

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
            onMapCreated: (GoogleMapController controller) {
              _controller = controller;
              setMapStyle();
            },
          ),
          iconLocation(),
          SlidingUpPanel(
            maxHeight: _panelHeightOpen,
            minHeight: _panelHeightClosed,
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
