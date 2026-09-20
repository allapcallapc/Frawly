/// The only place in this package that makes network calls - every
/// operation here is a single HTTP request to the Frawly backend (a
/// Cloudflare Worker, see ../backend/src/index.ts for the routes), the
/// same REST API the Flutter app's ContainerService talks to (see
/// ../lib/services/container_service.dart, which this mirrors). This
/// package never touches D1/Cloudflare directly.

export type ContainerStatus = 'vacant' | 'frozen' | 'construction';

export interface Ingredient {
  name: string;
  quantity: string;
}

export interface Container {
  id: string;
  date: string | null;
  status: ContainerStatus;
  ingredients: Ingredient[];
}

export interface ExportDocument {
  version: number;
  exportedAt: string;
  containers: Container[];
}

export class FrawlyApiError extends Error {
  constructor(
    message: string,
    readonly status: number,
  ) {
    super(message);
    this.name = 'FrawlyApiError';
  }
}

export interface FrawlyClientConfig {
  backendUrl: string;
  passphrase: string;
  fetchImpl?: typeof fetch;
}

export class FrawlyClient {
  private readonly baseUrl: string;
  private readonly passphrase: string;
  private readonly fetchImpl: typeof fetch;

  constructor(config: FrawlyClientConfig) {
    this.baseUrl = config.backendUrl.endsWith('/')
      ? config.backendUrl.slice(0, -1)
      : config.backendUrl;
    this.passphrase = config.passphrase;
    // Cloudflare Workers' global fetch throws "Illegal invocation" if
    // called detached from globalThis (e.g. stored as a bare class field
    // and invoked as this.fetchImpl(...)) - bind it explicitly. Node
    // doesn't require this, which is why it only surfaced running under
    // the real Workers runtime (wrangler dev), not the Node-based tests.
    this.fetchImpl = config.fetchImpl ?? fetch.bind(globalThis);
  }

  private get headers(): Record<string, string> {
    return {
      Authorization: `Bearer ${this.passphrase}`,
      'Content-Type': 'application/json',
    };
  }

  private async errorMessage(response: Response, fallback: string): Promise<string> {
    try {
      const body = (await response.clone().json()) as unknown;
      if (body && typeof body === 'object' && 'error' in body && typeof body.error === 'string') {
        return body.error;
      }
    } catch {
      // Not JSON - fall through to the generic message.
    }
    // Includes the actual request URL/status/body so a misconfigured
    // BACKEND_URL, or a response that isn't actually coming from this
    // app's own Hono code (a Cloudflare-edge-level page, for instance),
    // is visible directly in the tool error instead of needing
    // server-side logs to diagnose.
    let bodyText = '';
    try {
      bodyText = (await response.clone().text()).slice(0, 300);
    } catch {
      // Body already consumed or unreadable - omit it.
    }
    return `${fallback} (${response.status} from ${response.url}) body=${JSON.stringify(bodyText)}`;
  }

  /** Verifies the URL/passphrase actually reach a Frawly backend. */
  async health(): Promise<boolean> {
    try {
      const response = await this.fetchImpl(`${this.baseUrl}/health`, { headers: this.headers });
      return response.status === 200;
    } catch {
      return false;
    }
  }

  /** Every registered container, sorted by prefix then numeric id suffix. */
  async getRegistry(): Promise<Container[]> {
    const response = await this.fetchImpl(`${this.baseUrl}/containers/registry`, {
      headers: this.headers,
    });
    if (!response.ok) {
      throw new FrawlyApiError(await this.errorMessage(response, 'Could not load the registry.'), response.status);
    }
    return (await response.json()) as Container[];
  }

  /** Containers filtered by status/search, sorted by date (vacant first). */
  async listContainers(options: { status?: ContainerStatus; search?: string } = {}): Promise<Container[]> {
    const params = new URLSearchParams();
    if (options.status) params.set('status', options.status);
    if (options.search?.trim()) params.set('search', options.search.trim());
    const query = params.toString();
    const response = await this.fetchImpl(`${this.baseUrl}/containers${query ? `?${query}` : ''}`, {
      headers: this.headers,
    });
    if (!response.ok) {
      throw new FrawlyApiError(await this.errorMessage(response, 'Could not load containers.'), response.status);
    }
    return (await response.json()) as Container[];
  }

  /** A single container, or null if `id` isn't registered. */
  async getContainer(id: string): Promise<Container | null> {
    const response = await this.fetchImpl(`${this.baseUrl}/containers/${encodeURIComponent(id)}`, {
      headers: this.headers,
    });
    if (response.status === 404) return null;
    if (!response.ok) {
      throw new FrawlyApiError(await this.errorMessage(response, `Could not load ${id}.`), response.status);
    }
    return (await response.json()) as Container;
  }

  /** Registers a single new (empty/vacant) container id. */
  async addContainer(id: string): Promise<void> {
    const response = await this.fetchImpl(`${this.baseUrl}/containers`, {
      method: 'POST',
      headers: this.headers,
      body: JSON.stringify({ id }),
    });
    if (response.status !== 201) {
      throw new FrawlyApiError(await this.errorMessage(response, `Could not add ${id}.`), response.status);
    }
  }

  /**
   * Adds every "<prefix>-<n>" for n in [from, to] not already registered -
   * existing ids are skipped, not rejected. Returns the ids actually added.
   */
  async addContainerRange(options: { prefix: string; from: number; to: number }): Promise<string[]> {
    const response = await this.fetchImpl(`${this.baseUrl}/containers/range`, {
      method: 'POST',
      headers: this.headers,
      body: JSON.stringify(options),
    });
    if (!response.ok) {
      throw new FrawlyApiError(await this.errorMessage(response, 'Could not add the range.'), response.status);
    }
    const body = (await response.json()) as { added: string[] };
    return body.added;
  }

  /** Removes a container from the registry, deleting its data with it. */
  async removeContainer(id: string): Promise<void> {
    const response = await this.fetchImpl(`${this.baseUrl}/containers/${encodeURIComponent(id)}`, {
      method: 'DELETE',
      headers: this.headers,
    });
    if (response.status !== 204) {
      throw new FrawlyApiError(await this.errorMessage(response, `Could not remove ${id}.`), response.status);
    }
  }

  /** Resets every one of `ids` to vacant/null date/no ingredients. */
  async emptyContainers(ids: string[]): Promise<string[]> {
    const response = await this.fetchImpl(`${this.baseUrl}/containers/empty`, {
      method: 'POST',
      headers: this.headers,
      body: JSON.stringify({ ids }),
    });
    if (!response.ok) {
      throw new FrawlyApiError(await this.errorMessage(response, 'Could not empty containers.'), response.status);
    }
    const body = (await response.json()) as { emptied: string[] };
    return body.emptied;
  }

  /** Updates a single container's date/status/ingredients. */
  async updateContainer(
    id: string,
    fields: { date: string | null; status: ContainerStatus; ingredients: Ingredient[] },
  ): Promise<Container> {
    const response = await this.fetchImpl(`${this.baseUrl}/containers/${encodeURIComponent(id)}`, {
      method: 'PATCH',
      headers: this.headers,
      body: JSON.stringify(fields),
    });
    if (!response.ok) {
      throw new FrawlyApiError(await this.errorMessage(response, `Could not save ${id}.`), response.status);
    }
    return (await response.json()) as Container;
  }

  /** Overwrites every target container's date/status/ingredients atomically. */
  async createFilling(fields: {
    targetIds: string[];
    date: string | null;
    status: ContainerStatus;
    ingredients: Ingredient[];
  }): Promise<string[]> {
    const response = await this.fetchImpl(`${this.baseUrl}/fillings`, {
      method: 'POST',
      headers: this.headers,
      body: JSON.stringify(fields),
    });
    if (!response.ok) {
      throw new FrawlyApiError(await this.errorMessage(response, 'Could not save the filling.'), response.status);
    }
    const body = (await response.json()) as { updated: string[] };
    return body.updated;
  }

  /** The full registry + all container data, for backup/inspection. */
  async exportAll(): Promise<ExportDocument> {
    const response = await this.fetchImpl(`${this.baseUrl}/export`, { headers: this.headers });
    if (!response.ok) {
      throw new FrawlyApiError(await this.errorMessage(response, 'Could not export data.'), response.status);
    }
    return (await response.json()) as ExportDocument;
  }
}
