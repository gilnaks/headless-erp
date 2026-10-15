/** Client navigation. Route setup registers the router; until then, assign the location. */

export class NotFoundError extends Error {
    constructor() {
        super("Not found");
        this.name = "NotFoundError";
    }
}

/** Thrown after `redirect` when the caller must stop (there is no signed-in user to return). */
export class Redirecting extends Error {
    constructor() {
        super("Redirecting");
        this.name = "Redirecting";
    }
}

type Go = (to: string) => void;

let go: Go = (to) => {
    window.location.assign(to);
};

export function registerNavigate(navigate: Go) {
    go = navigate;
}

/** Leave the current screen and stop the caller. Forms treat `Redirecting` as success. */
export function redirect(to: string): never {
    go(to);
    throw new Redirecting();
}

export async function afterRedirect<T>(work: Promise<T>): Promise<T | undefined> {
    try {
        return await work;
    } catch (error) {
        if (error instanceof Redirecting) return undefined;
        throw error;
    }
}

export function notFound(): never {
    throw new NotFoundError();
}
