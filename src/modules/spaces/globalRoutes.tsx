import { Route } from "react-router-dom";
import Profile from "@/pages/Profile";
import Settings from "@/pages/Settings";
import Sessions from "@/pages/Sessions";
import Help from "@/pages/Help";

/** Routes available in all spaces (no space prefix) */
export const globalSpaceRoutes = (
  <>
    <Route path="/profile" element={<Profile />} />
    <Route path="/settings" element={<Settings />} />
    <Route path="/sessions" element={<Sessions />} />
    <Route path="/help" element={<Help />} />
  </>
);
