# `/admin/integrations` — Integration Hub Page Reference

> Replication guide for the **Integration Hub** admin page. Use this when porting the page to a copy/fork of SJ Control Tower Framework.

**Route:** `/admin/integrations`  
**Page component:** `src/pages/admin/Integrations.tsx`  
**Access:** Admin role (`AdminRoute` guard via `src/modules/admin/routes.tsx`)

---

## Page purpose

The Integration Hub is the central admin UI to:

- Browse third-party integrations grouped by category
- Connect/configure providers (API keys or OAuth)
- Set org-wide defaults per category (AI agent provider, CRM, PM, meetings, email)
- Trigger sync jobs from hub cards (where implemented)
- Navigate to provider-specific configuration pages

---

## UI layout

```
┌─────────────────────────────────────────────────────────────────┐
│ Integration Hub                          [View Analytics]         │
│ Connect, configure, and manage third-party REST API integrations│
├─────────────────────────────────────────────────────────────────┤
│ [🔍 Search integrations...]                                       │
├─────────────────────────────────────────────────────────────────┤
│ [AI Providers 3/5] [Meeting Platforms 2/4] [Email ...] ...     │  ← category tabs
├─────────────────────────────────────────────────────────────────┤
│ (AI tab only) Agent AI provider access bar                        │
│   Admin default only | Users can choose    Default: OpenRouter ★ │
├─────────────────────────────────────────────────────────────────┤
│ (non-AI tabs) Category default bar (CRM / PM / meetings / email) │
├─────────────────────────────────────────────────────────────────┤
│ ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐                      │
│ │Provider│ │Provider│ │Provider│ │Provider│   ← 4-col card grid  │
│ │  Card  │ │  Card  │ │  Card  │ │  Card  │                      │
│ └────────┘ └────────┘ └────────┘ └────────┘                      │
└─────────────────────────────────────────────────────────────────┘
```

### Key UI elements

| Element | Component | Behavior |
|---------|-----------|----------|
| Search | `Input` in `Integrations.tsx` | Filters providers in active tab by name, slug, description |
| Category tabs | `Tabs` + `useProvidersGroupedByCategory()` | Shows `connected/total` badge per category |
| Provider cards | `ProviderCard` | Click navigates to configure page; star sets org default |
| AI access bar | `AIAgentAccessInline` | Only on **AI Providers** tab; toggles `admin_locked` vs `user_choice` |
| Category access bar | `CategoryProviderAccessInline` | On CRM, PM, meetings, email, storage tabs |
| Analytics button | navigates to `/admin/integrations/analytics` | Usage stats dashboard |

### Provider card states

| State | Visual |
|-------|--------|
| Not configured | Grey badge, auth type shown (`api key`, `oauth2`) |
| Connected | Blue badge, optional **Sync now**, **Use for agents** (AI tab) |
| Org default | Blue border + star badge (`Agent default` or `Default`) |
| Coming soon | Dimmed card, disabled button |
| Inactive for category | Dimmed + "Connected, not active" badge |

---

## All integration categories

Data comes from `integration_categories` (seeded in `supabase/migrations/20260103_integration_hub_seed_data.sql`).

| # | Name | Slug | Icon | Enabled in hub |
|---|------|------|------|----------------|
| 1 | AI Providers | `ai-providers` | Brain | ✅ |
| 2 | Meeting Providers | `meeting-providers` | Video | ✅ |
| 3 | Email Providers | `email-providers` | Mail | ✅ |
| 4 | CRM Systems | `crm-systems` | Users | ✅ |
| 5 | Project Management | `project-management` | Kanban | ✅ |
| 6 | Storage & Productivity | `storage-productivity` | Cloud | ✅ |
| 7 | Authentication | `authentication` | Shield | ❌ (seeded `enabled = false`) |

---

## All integration providers (complete catalog)

Providers are rows in `integration_providers`. The hub reads them at runtime; you do **not** hardcode the list in the React page.

### AI Providers (`ai-providers`)

| Name | Slug | Auth | Hub status | Configure route | Notes |
|------|------|------|------------|-----------------|-------|
| OpenAI | `openai` | `api_key` | Available | `/admin/integrations/openai` | Links to `ai_providers` table |
| Anthropic Claude | `anthropic` | `api_key` | Available | `/admin/integrations/anthropic` | |
| Google Gemini | `google-gemini` | `api_key` | Available | `/admin/integrations/google-gemini` | |
| Perplexity | `perplexity` | `api_key` | Available | `/admin/integrations/perplexity` | |
| OpenRouter | `openrouter` | `api_key` | Available | `/admin/integrations/openrouter` | Added in `20260630120000_openrouter_integration.sql` |

**AI-specific behavior:** Star on a connected card sets the org **agent default** (`ai_model_policy.default_provider_slug`). The inline bar toggles whether users can pick their own provider (`selection_mode`: `admin_locked` | `user_choice`).

---

### Meeting Providers (`meeting-providers`)

| Name | Slug | Auth | Hub status | Configure route | Sync on hub card |
|------|------|------|------------|-----------------|------------------|
| Zoom | `zoom` | `oauth2` | Available | `/admin/integrations/zoom` | ✅ |
| Microsoft Teams | `microsoft-teams` | `oauth2` | Available | `/admin/integrations/microsoft-teams` | ✅ |
| Google Meet | `google-meet` | `oauth2` | Available | `/admin/integrations/google-meet` | ✅ |
| Fellow | `fellow` | `api_key` | Available | `/admin/integrations/fellow` | ❌ |
| Cisco Webex | `webex` | `oauth2` | Coming soon | `/admin/integrations/webex` | ❌ |
| GoToMeeting | `gotomeeting` | `oauth2` | Coming soon | `/admin/integrations/gotomeeting` | ❌ |

**Sub-routes (dedicated pages):**

- `/admin/integrations/zoom/meetings`
- `/admin/integrations/zoom/documentation`
- `/admin/integrations/microsoft-teams/meetings`
- `/admin/integrations/google-meet/meetings`

---

### Email Providers (`email-providers`)

| Name | Slug | Auth | Hub status | Configure route | Sync on hub card |
|------|------|------|------------|-----------------|------------------|
| SendGrid | `sendgrid` | `api_key` | Available | `/admin/integrations/sendgrid` | ✅ |
| Microsoft Outlook | `outlook` | `oauth2` | Available | `/admin/integrations/outlook` | ✅ |
| Mailgun | `mailgun` | `api_key` | Coming soon | `/admin/integrations/mailgun` | ❌ |
| Postmark | `postmark` | `api_key` | Coming soon | `/admin/integrations/postmark` | ❌ |
| Amazon SES | `amazon-ses` | `service_account` | Coming soon | `/admin/integrations/amazon-ses` | ❌ |
| Resend | `resend` | `api_key` | Coming soon | `/admin/integrations/resend` | ❌ |

---

### CRM Systems (`crm-systems`)

| Name | Slug | Auth | Hub status | Configure route | Sync on hub card |
|------|------|------|------------|-----------------|------------------|
| Zoho CRM | `zoho-crm` | `oauth2` | **Available** (only actionable CRM) | `/admin/integrations/zoho-crm` | ✅ |
| Salesforce | `salesforce` | `oauth2` | Coming soon | hidden from hub* | ❌ |
| HubSpot | `hubspot` | `oauth2` | Coming soon | hidden from hub* | ❌ |
| Pipedrive | `pipedrive` | `api_key` | Coming soon | hidden from hub* | ❌ |

\* CRM tab filters out providers where `is_coming_soon = true` AND `is_available = false` (see `useProvidersGroupedByCategory` in `src/hooks/useIntegrations.ts`).

---

### Project Management (`project-management`)

| Name | Slug | Auth | Hub status | Configure route | Sync on hub card |
|------|------|------|------------|-----------------|------------------|
| ActiveCollab | `activecollab` | `oauth2` / token | Available | `/admin/integrations/activecollab` | ✅ |
| ClickUp | `clickup` | `oauth2` | Available | `/admin/integrations/clickup` | ✅ |
| Jira | `jira` | `oauth2` | Available | `/admin/integrations/jira` | ✅ |
| Float | `float` | `api_key` | Available | `/admin/integrations/float` | ❌ (sync on detail page) |
| Workamajig | `workamajig` | `api_key` | Available | `/admin/integrations/workamajig` | ✅ |
| Asana | `asana` | `oauth2` | Coming soon | `/admin/integrations/asana` | ❌ |
| Monday.com | `monday` | `api_key` | Coming soon | `/admin/integrations/monday` | ❌ |
| Trello | `trello` | `api_key` | Coming soon | `/admin/integrations/trello` | ❌ |

---

### Storage & Productivity (`storage-productivity`)

| Name | Slug | Auth | Hub status | Configure route | Knowledge sync |
|------|------|------|------------|-----------------|----------------|
| Google Drive | `google-drive` | `oauth2` | Available | `/admin/integrations/google-drive` | ✅ |
| Confluence | `confluence` | `api_key` | Available | `/admin/integrations/confluence` | ✅ |
| SharePoint | `sharepoint` | `oauth2` | Available | `/admin/integrations/sharepoint` | ✅ |
| Google Workspace | `google-workspace` | `oauth2` | Coming soon | `/admin/integrations/google-workspace` | — |
| Microsoft 365 | `microsoft-365` | `oauth2` | Coming soon | `/admin/integrations/microsoft-365` | — |

**Knowledge-capable slugs** (for primary knowledge source selection):  
`confluence`, `sharepoint`, `google-drive`, `google-workspace`, `microsoft-365`, `notion`, `dropbox`

---

### Authentication (`authentication`) — category disabled

| Name | Slug | Auth | Notes |
|------|------|------|-------|
| Google Login | `google-login` | `oauth2` | SSO; managed under Security settings, not hub tab |

---

## Routes (admin module)

Defined in `src/modules/admin/routes.tsx`:

| Path | Component | Purpose |
|------|-----------|---------|
| `/admin/integrations` | `Integrations` | **Main hub page** |
| `/admin/integrations/analytics` | `IntegrationAnalytics` | Usage analytics |
| `/admin/integrations/oauth/callback` | `OAuthCallback` | OAuth return handler |
| `/admin/integrations/microsoft-teams` | `MicrosoftTeamsIntegration` | Dedicated Teams admin |
| `/admin/integrations/microsoft-teams/meetings` | `TeamsMeetings` | Synced Teams meetings |
| `/admin/integrations/zoom` | `ZoomIntegration` | Dedicated Zoom admin |
| `/admin/integrations/zoom/meetings` | `ZoomMeetings` | Synced Zoom meetings |
| `/admin/integrations/zoom/documentation` | `ZoomDocumentation` | Zoom setup docs |
| `/admin/integrations/google-meet` | `GoogleMeetIntegration` | Dedicated Google Meet admin |
| `/admin/integrations/google-meet/meetings` | `GoogleMeetMeetings` | Synced Meet meetings |
| `/admin/integrations/google-drive` | `GoogleDriveIntegration` | Dedicated Google Drive admin |
| `/admin/integrations/clickup` | `ClickUpIntegration` | Dedicated ClickUp admin |
| `/admin/integrations/activecollab` | `ActiveCollabIntegration` | Dedicated ActiveCollab admin |
| `/admin/integrations/sendgrid` | `SendGrid` | Dedicated SendGrid admin |
| `/admin/integrations/:slug` | `ProviderDetail` | **Generic** dynamic form for all other slugs |

**Card navigation logic** (`ProviderCard.tsx`):

- `zoom` → `/admin/integrations/zoom`
- `microsoft-teams` → `/admin/integrations/microsoft-teams`
- All others → `/admin/integrations/{slug}`

---

## Data model (database)

### Core tables

| Table | Purpose |
|-------|---------|
| `integration_categories` | Tab groups (AI, meetings, email, …) |
| `integration_providers` | Each service (OpenAI, Zoom, Zoho, …) |
| `integration_fields` | Dynamic form fields per provider |
| `integration_services` | Sub-services per provider (e.g. Zoom recordings) |
| `organization_integrations` | Per-user org config + `connection_status` |
| `integration_usage_logs` | API call analytics |
| `integration_settings` | Per-category primary provider + active slugs |
| `user_oauth_tokens` | Per-user OAuth tokens (meetings, Outlook, etc.) |
| `oauth_states` | CSRF state for OAuth flows |
| `ai_model_policy` | AI agent default provider + selection mode |

### Connection status values

`connected` | `disconnected` | `error` | `testing`

The hub badge uses `organization_integrations.connection_status` for the signed-in admin user.

---

## Frontend architecture

### Data loading

```
Integrations.tsx
  └── useProvidersGroupedByCategory()
        ├── useIntegrationCategories()     → integration_categories
        ├── useIntegrationProviders()      → integration_providers
        └── useOrganizationIntegrations()  → organization_integrations + provider join
```

### Key files to copy

```
src/pages/admin/
  Integrations.tsx              ← main hub page
  ProviderDetail.tsx            ← generic provider config
  OAuthCallback.tsx
  IntegrationAnalytics.tsx
  integrations/
    ZoomIntegration.tsx
    ZoomMeetings.tsx
    ZoomDocumentation.tsx
    MicrosoftTeamsIntegration.tsx
    TeamsMeetings.tsx
    GoogleMeetIntegration.tsx
    GoogleMeetMeetings.tsx
    GoogleDriveIntegration.tsx
    ClickUpIntegration.tsx
    ActiveCollabIntegration.tsx
    SendGrid.tsx

src/components/integrations/
  ProviderCard.tsx
  DynamicFormField.tsx
  AIAgentAccessInline.tsx
  CategoryProviderAccessInline.tsx
  ProviderDisplayDestinations.tsx
  ServiceManagement.tsx
  UsageStats.tsx
  AIModelsSection.tsx
  AIProviderConnectSettings.tsx
  IntegrationTabQuickControls.tsx
  IntegrationPreferencesSection.tsx
  IntegrationCategoryTabPreferences.tsx
  IntegrationMultiSelect.tsx

src/hooks/
  useIntegrations.ts
  useIntegrationSettings.ts
  useSetProviderAsDefault.ts
  useUserIntegrations.ts
  useIntegrationSync.ts
  useAIModelPolicy.ts
  usePMSync.ts / useCrmSync.ts / useMeetingSync.ts / useEmailSync.ts
  useSyncTeamsMeetings.ts
  useOrgIntegrationOverview.ts

src/lib/
  integration-utils.ts
  integration-preferences.ts
  integration-display.ts
  org-integration-overview.ts
  ai-model-policy.ts

src/modules/admin/routes.tsx   ← register routes
src/shared/data/navigationStructure.ts  ← sidebar link
```

### Hooks used on the hub page

| Hook | Role |
|------|------|
| `useProvidersGroupedByCategory` | Categories + providers + connection counts |
| `useAIModelPolicy` | AI default provider + selection mode |
| `usePrimaryByCategorySettings` | CRM/PM/meeting/email primary slugs |
| `useSetProviderAsDefault` | Star button → set org default |
| `usePMSync` / `useCrmSync` / `useMeetingSync` / `useEmailSync` | Hub card "Sync now" |
| `useSyncTeamsMeetings` | Special Teams sync path |

---

## Backend (Supabase)

### Migrations to apply (minimum)

Run in order (full list under `supabase/migrations/`):

1. `20260103_integration_hub_schema.sql` — tables + RLS
2. `20260103_integration_hub_seed_data.sql` — categories + base providers
3. `20260616140000_integration_settings.sql` — org defaults per category
4. `20260625120000_integration_config_encryption.sql` — encrypted credentials
5. Provider-specific migrations as needed (Zoho, Jira, OpenRouter, Fellow, Outlook, Confluence, SharePoint, Float, …)

### Edge functions (integration-related)

| Function | Purpose |
|----------|---------|
| `integration-config` | Get/save org config (masks secrets) |
| `validate-api-key` | Test API key providers |
| `user-oauth-connect` | Start OAuth (reads org client id/secret) |
| `user-oauth-callback` | Exchange code → `user_oauth_tokens` |
| `user-oauth-refresh` | Refresh expired tokens |
| `sync-clickup` | ClickUp PM sync |
| `sync-projects-jira` / `sync-tasks-jira` | Jira sync |
| `sync-projects-activecollab` | ActiveCollab sync |
| `sync-float-schedule` | Float schedule sync |
| `zoho-crm-sync` (+ zoho-deal-* functions) | Zoho CRM sync |
| `sync-confluence-knowledge` | Confluence → knowledge base |
| `sync-sharepoint-knowledge` | SharePoint → knowledge base |
| `outlook-send-test-email` | Outlook test from ProviderDetail |
| `fellow-api` | Fellow meeting API proxy |

---

## Sync providers (implemented in app code)

Defined in `src/lib/integration-preferences.ts`:

| Category | Slugs with hub "Sync now" |
|----------|---------------------------|
| Project Management | `clickup`, `jira`, `activecollab`, `workamajig` |
| CRM | `zoho-crm` |
| Meetings | `zoom`, `microsoft-teams`, `google-meet` |
| Email | `sendgrid`, `outlook` |

Float sync is triggered from `ProviderDetail` only (`sync-float-schedule`).

---

## OAuth flow (summary)

```
Admin saves Client ID + Secret → organization_integrations.config
User clicks Connect on ProviderDetail
  → user-oauth-connect (stores state in oauth_states)
  → redirect to provider
  → provider redirects to SUPABASE_URL/functions/v1/user-oauth-callback
  → tokens saved to user_oauth_tokens
  → redirect back to app (e.g. /admin/integrations/zoom)
```

OAuth callback page: `/admin/integrations/oauth/callback` (`OAuthCallback.tsx`)

---

## Replication checklist (copy project)

### 1. Database

- [ ] Apply integration hub schema + seed migrations
- [ ] Apply provider-specific migrations for integrations you need
- [ ] Verify `integration_categories.enabled = true` for hub tabs
- [ ] Verify each provider: `is_available`, `is_coming_soon`, `integration_fields` rows

### 2. Edge functions

- [ ] Deploy `integration-config`, `validate-api-key`, OAuth trio
- [ ] Deploy sync functions for providers you enable
- [ ] Set secrets (provider API keys are org-level in DB, not env)

### 3. Frontend

- [ ] Copy files listed in [Key files to copy](#key-files-to-copy)
- [ ] Register routes in `src/modules/admin/routes.tsx`
- [ ] Add sidebar entry: `{ title: "Integrations", href: "/admin/integrations", icon: "Zap" }`
- [ ] Ensure Supabase client + React Query provider are configured

### 4. Smoke test

- [ ] `/admin/integrations` loads all category tabs with correct counts
- [ ] Search filters providers within active tab
- [ ] Configure an API-key provider (e.g. OpenAI) → card shows **Connected**
- [ ] Star sets default on AI tab; inline bar persists selection mode
- [ ] OAuth provider (e.g. Zoom) completes connect flow
- [ ] "Sync now" runs without error for an enabled sync provider

---

## Related documentation

| Doc | Contents |
|-----|----------|
| [INTEGRATION_HUB_IMPLEMENTATION_GUIDE.md](../INTEGRATION_HUB_IMPLEMENTATION_GUIDE.md) | Full blueprint: schema, edge functions, OAuth, adding providers |
| [integration-preferences-spec.md](./integration-preferences-spec.md) | Primary integrations + knowledge sources |
| [api-reference.md](./api-reference.md) | Integration API surface |
| [data-flows.md](./data-flows.md) | End-to-end data flows |

---

## Adding a new provider to the hub

1. **SQL:** Insert into `integration_providers` (+ `integration_fields`, optional `integration_services`)
2. **Edge function:** Add validation in `validate-api-key` and/or OAuth config in `user-oauth-connect`
3. **Frontend:** Usually no hub change — `ProviderDetail` renders fields dynamically
4. **Optional:** Dedicated page under `src/pages/admin/integrations/` + route **before** `:slug`
5. **Sync:** Add slug to `PM_SYNC_PROVIDER_SLUGS` (or CRM/meeting/email lists) + edge function

See section 10 in `INTEGRATION_HUB_IMPLEMENTATION_GUIDE.md` for the full walkthrough.
