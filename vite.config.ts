import { defineConfig } from "vite";
import { svelte } from "@sveltejs/vite-plugin-svelte";
import RubyPlugin from "vite-plugin-ruby";
import tailwindcss from "@tailwindcss/vite";
import { resolve } from "path";

export default defineConfig({
  plugins: [
    RubyPlugin(),
    svelte(),
    tailwindcss(),
  ],
  resolve: {
    alias: {
      "$components": resolve(__dirname, "app/frontend/components"),
      "$lib": resolve(__dirname, "app/frontend/lib"),
      "$pages": resolve(__dirname, "app/frontend/pages"),
    },
  },
});
