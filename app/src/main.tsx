// EUROPESIP · Hello DX: entry point. Mounts the app in its own root element, so it can live next
// to the DX theme and other portlets on the same page.
import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import App from './App.tsx'
import './App.css'

createRoot(document.getElementById('europesip-hello-dx-root')!).render(
  <StrictMode>
    <App />
  </StrictMode>,
)
