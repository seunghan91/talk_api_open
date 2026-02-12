import { createInertiaApp } from "@inertiajs/svelte";
import { mount } from "svelte";
import "../styles/app.css";

createInertiaApp({
  resolve: (name) => {
    const pages = import.meta.glob("../pages/**/*.svelte", { eager: true });
    const page = pages[`../pages/${name}.svelte`];
    if (!page) {
      throw new Error(`Page not found: ${name}`);
    }
    return page;
  },
  setup({ el, App, props }) {
    mount(App, { target: el, props });
  },
});
