import type { NextConfig } from "next";
const basePath = process.env.BASE_PATH ?? "/chat";

const nextConfig: NextConfig = {
  // Enable static exports
  output: "export",

  // Disable image optimization since it's not supported in static exports
  images: {
    unoptimized: true,
  },

  // Configure base path for GitHub Pages (repo/chat)
  basePath,

  // Configure asset prefix for GitHub Pages - helps with static asset loading
  assetPrefix: `${basePath}/`,

  // Configure trailing slashes (recommended for static exports)
  trailingSlash: true,
};

export default nextConfig;
