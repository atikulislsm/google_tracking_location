import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GPS Location Sender',
      home: LocationSender(),
    );
  }
}

class LocationSender extends StatefulWidget {
  @override
  _LocationSenderState createState() => _LocationSenderState();
}
Position ? position;
class _LocationSenderState extends State<LocationSender> {
  String _location = "Fetching location...";
  bool _isSending = false;
  late GoogleMapController _mapController;
  LatLng _currentPosition=LatLng(0, 0);
  Set<Marker> _markers={};
  Set<Circle> _circle={};
  Set<Polyline> _polyLine={};
  Set<Polygon> _polyGone={};

  @override
  void initState() {
    super.initState();
    _fetchAndSendLocation();
    listenCurrentLocation();
  }

  // Fetch the GPS location
  Future<void> _fetchAndSendLocation() async {
    Position position;
    try {
      // Check location permissions
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _location = "Location services are disabled.";
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _location = "Location permissions are denied.";
          });
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _location = "Location permissions are permanently denied.";
        });
        return;
      }
      // Get the current position
      position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.bestForNavigation,
              locationSettings: const LocationSettings(
                // distanceFilter: 10,
                timeLimit: Duration(seconds: 2),
      )
      );

      String location = "${position.latitude}, ${position.longitude}";

      setState(() {
        _location = location;
        _currentPosition=LatLng(position.latitude, position.longitude);
        _markers.add(
            Marker(
                markerId: MarkerId('currentLocation'),
                position: _currentPosition,
                infoWindow: InfoWindow(title: 'Current location $location'),
              draggable: true,
            )
        );
        _circle.add(
            Circle(
          circleId: CircleId('initial-circle'),
              fillColor: Colors.red.withOpacity(0.3),
              strokeWidth: 2,
              center: LatLng(position.latitude, position.longitude),
              radius: 30,
              strokeColor: Colors.blue,
              visible: true

        ));
        _polyLine.add(
            Polyline(
            polylineId: PolylineId('polyLine-id'),
          color: Colors.amber,
          width: 4,
          jointType: JointType.round,
          points: <LatLng> [
            LatLng(23.87811590899912, 90.36604544762169),
            LatLng(23.874230876715714, 90.37256857994618),

          ]
        ));
        _polyGone.add(
            Polygon(
              fillColor: Colors.blue.withOpacity(0.4),
                strokeColor: Colors.black,
                strokeWidth: 2,
                polygonId: PolygonId('poly-id'),
              points: <LatLng>[
                LatLng(23.87811590899912, 90.36604544762169),
                LatLng(23.874230876715714, 90.37256857994618),
                LatLng(23.872239521474018, 90.364253891676),
                LatLng(23.868205527564093, 90.37143773420323),
              ]

        ));
      });
      //Move the map to the current location
      _mapController.animateCamera(
        CameraUpdate.newCameraPosition(
            CameraPosition(target: _currentPosition, zoom: 15)
        )
      );
      // Send the location to the server
      await _sendLocationToServer(position.latitude, position.longitude);
    } catch (e) {
      setState(() {
        _location = "Failed to get location: $e";
      });
    }
  }

  // Send the GPS location to the specific IP
  Future<void> _sendLocationToServer(double latitude, double longitude) async {
    setState(() {
      _isSending = true;
    });

    String serverIP = 'http://175.29.147.204:6868/endpoint'; //this is my server ip here endpoint is "endpoint"

    try {
      final response = await http.post(
        Uri.parse(serverIP),
        headers: <String, String>{
          'Content-Type': 'application/json',
        },
        body: jsonEncode(<String, double>{
          'latitude': latitude,
          'longitude': longitude,
        }),
      );
      if (response.statusCode == 200) {
        setState(() {
          _location = "Location sent successfully!";
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Send Successfull')));
          print('send succuessfully');
        });
      } else {
        setState(() {
          _location = "Failed to send location. Error: ${response.statusCode}";
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error')));
        });
      }
    } catch (e) {
      setState(() {
        _location = "Failed to send location: $e";
      });
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }
  void _onMapCreate(GoogleMapController controller){
    _mapController=controller;
  }
  Future<void> listenCurrentLocation() async {
    final isGranted=await isLocationPermisson();
    if(isGranted){
      final isServiceEnabled=await checkGpsServiceEnable();
      if(isServiceEnabled){
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            // timeLimit: Duration(seconds: 3),
            distanceFilter: 10,
            accuracy: LocationAccuracy.bestForNavigation
          )
        ).listen((pos){
          print(pos);
        });
      }
    }else{
      final result=await reqLocationPermission();
      if(result){
        getCurrentLocation();
      }
    }
    Geolocator.getPositionStream().listen((pos){

    });
  }
  Future<void> getCurrentLocation() async{
    final isGranted=await isLocationPermisson();
    if(isGranted){
      final isServiceEnabled=await checkGpsServiceEnable();
      if(isServiceEnabled){
        Position p=await Geolocator.getCurrentPosition();
        position=p;
        setState(() {
        });
      }
    }else{
      final result=await reqLocationPermission();
      if(result){
        getCurrentLocation();
      }
    }
  }
  Future<bool> isLocationPermisson() async{
    LocationPermission permission=await Geolocator.checkPermission();
    if(permission==LocationPermission.always || permission==LocationPermission.whileInUse){
      return true;
    }else{
      return false;
    }
  }
  Future<bool> reqLocationPermission() async{
    LocationPermission permission=await Geolocator.requestPermission();
    if(permission==LocationPermission.always || permission==LocationPermission.whileInUse){
      return true;
    }else{
      return false;
    }
  }
  Future<bool> checkGpsServiceEnable() async{
    return await Geolocator.isLocationServiceEnabled();
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Send GPS Location'),
      ),
      body: Center(
        child: _isSending?
        CircularProgressIndicator():
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Expanded(
                    child: GoogleMap(
                      onTap: (LatLng? latlng){
                        print(latlng);
                      },
                      onMapCreated: _onMapCreate,
                      initialCameraPosition:
                          CameraPosition(target: _currentPosition,
                              zoom: 10
                          ),
                      zoomControlsEnabled: true,
                      zoomGesturesEnabled: true,
                      trafficEnabled: true,
                      markers: _markers,
                      circles: _circle,
                      polylines: _polyLine,
                      polygons: _polyGone,
                      myLocationEnabled: true,
                      myLocationButtonEnabled: true,
                    ),
                  ), 
            Text(_location),
            Text('My Current Location $position'),
            ElevatedButton(
              onPressed: _fetchAndSendLocation, child: Text('Send location Again'),
            ),
            ElevatedButton(onPressed: getCurrentLocation, child: Text('current positon'))
                ],
        ),
      ),
    );
  }
}
