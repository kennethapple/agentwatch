/** @type {import('next').NextConfig} */
const nextConfig = {
  output: 'standalone',  // Required for Cloud Run Docker deployment
  env: {
    NEXT_PUBLIC_AGENT_URL: process.env.NEXT_PUBLIC_AGENT_URL,
  },
}

export default nextConfig
