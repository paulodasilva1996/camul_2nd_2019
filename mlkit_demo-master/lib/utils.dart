import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:firebase_ml_vision/firebase_ml_vision.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart';
import 'package:path_provider/path_provider.dart';

typedef HandleDetection = Future<dynamic> Function(FirebaseVisionImage image);

Future<CameraDescription> getCamera(CameraLensDirection dir) async {
  return await availableCameras().then(
    (List<CameraDescription> cameras) => cameras.firstWhere(
          (CameraDescription camera) => camera.lensDirection == dir,
        ),
  );
}

Uint8List concatenatePlanes(List<Plane> planes) {
  final WriteBuffer allBytes = WriteBuffer();
  planes.forEach((Plane plane) => allBytes.putUint8List(plane.bytes));
  return allBytes.done().buffer.asUint8List();
}

FirebaseVisionImageMetadata buildMetaData(
  CameraImage image,
  ImageRotation rotation,
) {
  return FirebaseVisionImageMetadata(
    rawFormat: image.format.raw,
    size: Size(image.width.toDouble(), image.height.toDouble()),
    rotation: rotation,
    planeData: image.planes.map(
      (Plane plane) {
        return FirebaseVisionImagePlaneMetadata(
          bytesPerRow: plane.bytesPerRow,
          height: plane.height,
          width: plane.width,
        );
      },
    ).toList(),
  );
}

Future<dynamic> detect(
  CameraImage image,
  HandleDetection handleDetection,
  ImageRotation rotation,
) async {

   FirebaseVisionImage x = FirebaseVisionImage.fromBytes(
      concatenatePlanes(image.planes),
      buildMetaData(image, rotation),
    );
  
  return handleDetection(x,);
}

ImageRotation rotationIntToImageRotation(int rotation) {
  switch (rotation) {
    case 0:
      return ImageRotation.rotation0;
    case 90:
      return ImageRotation.rotation90;
    case 180:
      return ImageRotation.rotation180;
    default:
      assert(rotation == 270);
      return ImageRotation.rotation270;
  }
}

Future<Image> saveImageToFile(CameraImage image) async {
      try {
        final int width = image.width;
        final int height = image.height;
        final int uvRowStride = image.planes[1].bytesPerRow;
        final int uvPixelStride = image.planes[1].bytesPerPixel;

        print("uvRowStride: " + uvRowStride.toString());
        print("uvPixelStride: " + uvPixelStride.toString());
        
        // imgLib -> Image package from https://pub.dartlang.org/packages/image
        var img = Image(width, height); // Create Image buffer

        // Fill image buffer with plane[0] from YUV420_888
        for(int x=0; x < width; x++) {
          for(int y=0; y < height; y++) {
            final int uvIndex = uvPixelStride * (x/2).floor() + uvRowStride*(y/2).floor();
            final int index = y * width + x;

            final yp = image.planes[0].bytes[index];
            final up = image.planes[1].bytes[uvIndex];
            final vp = image.planes[2].bytes[uvIndex];
            // Calculate pixel color
            int r = (yp + vp * 1436 / 1024 - 179).round().clamp(0, 255);
            int g = (yp - up * 46549 / 131072 + 44 -vp * 93604 / 131072 + 91).round().clamp(0, 255);
            int b = (yp + up * 1814 / 1024 - 227).round().clamp(0, 255);     
            // color: 0x FF  FF  FF  FF 
            //           A   B   G   R
            img.data[index] = (0xFF << 24) | (b << 16) | (g << 8) | r;
          }
        }

        JpegEncoder jpegEncoder = new JpegEncoder (quality: 95);
        List<int> jpeg = jpegEncoder.encodeImage(img);
        //muteYUVProcessing = false;
        
        Directory directory = await getExternalStorageDirectory(); // AppData folder path      
        final myImagePath = '${directory.path}/MyImages' ;
        final myImgDir = await new Directory(myImagePath).create();
        DateTime ketF = new DateTime.now();
        String baru = "${ketF.year}${ketF.month}${ketF.day}";
        int rand = new Random().nextInt(100000);

        print ("CREATING IMAGE FILE!!!!");

        var kompresimg = new File("$myImagePath/image_$baru$rand.jpg")
          ..writeAsBytesSync(jpeg);

        //return Image.memory(png);
        return img;  
      } catch (e) {
        print(">>>>>>>>>>>> ERROR:" + e.toString());
      }
      return null;
  }

