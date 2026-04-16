/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{js,ts,jsx,tsx}'],
  theme: {
    extend: {
      colors: {
        primary: {
          DEFAULT: '#1E40AF',
          light: '#3B82F6',
          dark: '#1E3A8A',
        },
        risk: {
          high: '#DC2626',
          'high-light': '#EF4444',
          medium: '#F59E0B',
          'medium-light': '#FBBF24',
          low: '#16A34A',
          'low-light': '#22C55E',
        },
        app: {
          bg: '#F0F2F5',
          surface: '#FFFFFF',
          'text-primary': '#1F2937',
          'text-secondary': '#6B7280',
          border: '#E5E7EB',
        },
      },
      boxShadow: {
        card: '0 2px 10px rgba(0,0,0,0.04)',
        'card-active': '0 2px 10px rgba(0,0,0,0.08)',
      },
    },
  },
  plugins: [],
}
