{
  "targets": [
    {
      "target_name": "<(module_name)",
      "defines": [ "NAPI_CPP_EXCEPTIONS" ],
      "sources": [
        "src/noble_mac.mm",
        "src/napi_objc.mm",
        "src/ble_manager.mm",
        "src/objc_cpp.mm",
        "src/callbacks.cc"
      ],
      "include_dirs": [
        "<!@(node -p \"require('node-addon-api').include\")",
        "<!@(node -p \"require('napi-thread-safe-callback').include\")"
      ],
      "dependencies": [
        "<!(node -p \"require('node-addon-api').gyp\")"
      ],
      "cflags!": [ "-fno-exceptions" ],
      "cflags_cc!": [ "-fno-exceptions" ],
      "xcode_settings": {
        "GCC_ENABLE_CPP_EXCEPTIONS": "YES",
        "CLANG_CXX_LIBRARY": "libc++",
        "MACOSX_DEPLOYMENT_TARGET": "12.0",   
        "SDKROOT": "macosx",                  
        "ARCHS": [ "arm64", "x86_64" ],
        "OTHER_CFLAGS": [
          "-fobjc-arc"
        ],
        "ENABLE_BITCODE": "NO",              
        "DEAD_CODE_STRIPPING": "YES"
      },
      "link_settings": {
        "libraries": [
          "$(SDKROOT)/System/Library/Frameworks/CoreBluetooth.framework"
        ]
      },
      "msvs_settings": {
        "VCCLCompilerTool": {
          "ExceptionHandling": 1
        }
      },
      "product_dir": "<(module_path)"
    }
  ]
}