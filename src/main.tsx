import { createRoot } from "react-dom/client";
import "./index.css";
import { getEnvironmentErrorMessage, validateEnvironment } from "./lib/env-validator";

interface EnvironmentErrorScreenProps {
  missing: string[];
}

function EnvironmentErrorScreen({ missing }: EnvironmentErrorScreenProps): JSX.Element {
  return (
    <div className="min-h-screen bg-background text-foreground">
      <div className="mx-auto flex min-h-screen max-w-3xl items-center justify-center p-6">
        <div className="w-full rounded-lg border bg-card p-6 shadow-sm">
          <h1 className="text-2xl font-semibold">Project setup is incomplete</h1>
          <p className="mt-2 text-sm text-muted-foreground">
            The app cannot start until the required environment variables are set.
          </p>

          <div className="mt-6 rounded-md border bg-muted/40 p-4">
            <p className="text-sm font-medium">Missing variables</p>
            <ul className="mt-2 list-disc pl-5 text-sm text-muted-foreground">
              {missing.map((variable: string) => (
                <li key={variable}>
                  <code>{variable}</code>
                </li>
              ))}
            </ul>
          </div>

          <div className="mt-6 rounded-md border bg-muted/40 p-4">
            <p className="text-sm font-medium">How to fix it</p>
            <pre className="mt-2 whitespace-pre-wrap text-sm text-muted-foreground">
              {getEnvironmentErrorMessage(missing)}
            </pre>
          </div>
        </div>
      </div>
    </div>
  );
}

// Handle MSAL redirect before app renders
async function initializeApp(): Promise<void> {
  // Validate environment variables at startup
  const envValidation = validateEnvironment();
  const rootElement = document.getElementById("root");

  if (!rootElement) {
    throw new Error("Root element #root was not found.");
  }

  const root = createRoot(rootElement);

  if (!envValidation.valid) {
    console.error("⚠️  Application starting with missing environment variables.");
    console.error("Some features may not work correctly.");
    root.render(<EnvironmentErrorScreen missing={envValidation.missing} />);
    return;
  }

  try {
    // Dynamically import to avoid issues if MSAL not configured
    const { handleMSALRedirect } = await import("./lib/azureAuth");
    await handleMSALRedirect();
  } catch (error) {
    // MSAL not configured or error handling redirect - continue with app
    console.log("MSAL redirect handling skipped:", error);
  }

  // Render the app
  const { default: App } = await import("./App.tsx");
  root.render(<App />);
}

initializeApp();
