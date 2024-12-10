//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <navigator_plus/navigator_plus_plugin.h>

void fl_register_plugins(FlPluginRegistry* registry) {
  g_autoptr(FlPluginRegistrar) navigator_plus_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "NavigatorPlusPlugin");
  navigator_plus_plugin_register_with_registrar(navigator_plus_registrar);
}
