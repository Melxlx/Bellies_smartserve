import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../models/order_model.dart';
import 'free_search_service.dart';

class DeliveryLocationController extends ChangeNotifier {
  final FreeSearchService searchService = FreeSearchService();
  
  final nameController = TextEditingController();
  final contactController = TextEditingController();
  final houseUnitController = TextEditingController();
  final addressController = TextEditingController();
  final landmarkController = TextEditingController();

  LatLng? point;
  bool locationConfirmed = false;
  bool locating = false;
  bool searching = false;
  String? searchError;
  String? locationError;

  DeliveryLocationController({CustomerDetails? initialDetails}) {
    if (initialDetails != null) {
      nameController.text = initialDetails.name;
      contactController.text = initialDetails.contact;
      houseUnitController.text = initialDetails.houseUnit;
      addressController.text = initialDetails.address;
      landmarkController.text = initialDetails.landmark;
      if (initialDetails.latitude != null) {
        point = LatLng(initialDetails.latitude!, initialDetails.longitude!);
      }
      locationConfirmed = initialDetails.locationConfirmed;
    }
  }

  Future<void> useCurrentLocation() async {
    locating = true;
    locationError = null;
    notifyListeners();

    try {
      final position = await Geolocator.getCurrentPosition();
      point = LatLng(position.latitude, position.longitude);
      await reverseGeocode(point!);
    } catch (e) {
      locationError = "Could not get current location.";
    } finally {
      locating = false;
      notifyListeners();
    }
  }

  Future<void> reverseGeocode(LatLng p) async {
    searching = true;
    notifyListeners();
    try {
      final address = await searchService.reverseGeocode(p);
      if (address != null) {
        addressController.text = address;
      }
    } catch (e) {
      searchError = "Could not find address for this point.";
    } finally {
      searching = false;
      notifyListeners();
    }
  }

  void selectMapPoint(LatLng p) {
    point = p;
    locationConfirmed = true;
    reverseGeocode(p);
  }

  CustomerDetails buildDetails() {
    return CustomerDetails(
      name: nameController.text.trim(),
      contact: contactController.text.trim(),
      address: addressController.text.trim(),
      houseUnit: houseUnitController.text.trim(),
      landmark: landmarkController.text.trim(),
      notes: '',
      latitude: point?.latitude,
      longitude: point?.longitude,
      locationConfirmed: locationConfirmed,
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    contactController.dispose();
    houseUnitController.dispose();
    addressController.dispose();
    landmarkController.dispose();
    super.dispose();
  }
}
