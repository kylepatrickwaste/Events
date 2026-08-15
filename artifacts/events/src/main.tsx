import { createRoot } from 'react-dom/client';

import { setBaseUrl } from '@workspace/api-client-react';

import App from './App';

import './index.css';

// All API calls go to the ASP.NET Core backend. The generated client issues
// relative `/api/...` paths, and this base URL is prepended to them.
setBaseUrl('https://api.kpcf.us');

createRoot(document.getElementById('root')!).render(<App />);
