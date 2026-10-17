// Identity of the root Navigation stack.
//
// The picture-in-picture controller caches the page it was started from so the
// "restore" control can bring the reader back to it. That only works when the
// Navigation component carries an id, and both the Hds and the plain fallback
// Navigation in the root page have to use the same one.
export const MAIN_NAVIGATION_ID: string = 'harmonyx-main-navigation';
