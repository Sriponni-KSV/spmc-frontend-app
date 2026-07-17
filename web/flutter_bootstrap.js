{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  serviceWorkerSettings: {
    serviceWorkerVersion: {{flutter_service_worker_version}},
  },
  onEntrypointLoaded: async function(engineInitializer) {
    const appRunner = await engineInitializer.initializeEngine({
      renderer: "html",  // Use HTML renderer instead of CanvasKit to avoid
                         // LateInitializationError: _handledContextLostEvent
                         // (Flutter 3.22+ CanvasKit WebGL context-loss bug)
    });
    await appRunner.runApp();
  }
});
