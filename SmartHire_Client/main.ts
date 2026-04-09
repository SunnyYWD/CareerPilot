import { createSSRApp } from "vue";
import App from "./src/App.vue";
import { setupStore } from "./src/store";

export function createApp() {
  const app = createSSRApp(App);
  
  setupStore(app);
  
  return {
    app,
  };
}
