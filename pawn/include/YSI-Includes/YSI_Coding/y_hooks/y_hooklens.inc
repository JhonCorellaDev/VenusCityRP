#if !defined MAX_HOOK_REPLACEMENTS
    #define MAX_HOOK_REPLACEMENTS (16)
#endif

// Generate a function name using only ONE of the parts, so two replacements for
// the same long name will collide at compile-time
#define DEFINE_HOOK_REPLACEMENT(%0,%1); forward @_yH%0(); public @_yH%0() { _Hooks_AddReplacement(#%0, #%1); }

// Strip spaces from the generated function name.
#define @_yH%0\32;%1(%2) @_yH%0%1(%2)

// Create the default replacements.
DEFINE_HOOK_REPLACEMENT(Checkpoint, CP );
DEFINE_HOOK_REPLACEMENT(Container , Cnt);
DEFINE_HOOK_REPLACEMENT(Inventory , Inv);
DEFINE_HOOK_REPLACEMENT(Dynamic   , Dyn);
DEFINE_HOOK_REPLACEMENT(TextDraw  , TD );
DEFINE_HOOK_REPLACEMENT(Update    , Upd);
DEFINE_HOOK_REPLACEMENT(Object    , Obj);
DEFINE_HOOK_REPLACEMENT(Command   , Cmd);

// Replaces the existing declarations.
enum E_HOOK_NAME_REPLACEMENT_DATA
{
    E_HOOK_NAME_REPLACEMENT_SHORT[4],
    E_HOOK_NAME_REPLACEMENT_LONG[16],
    E_HOOK_NAME_REPLACEMENT_MIN,
    E_HOOK_NAME_REPLACEMENT_LEN
}

static stock
    YSI_g_sReplacements[MAX_HOOK_REPLACEMENTS][E_HOOK_NAME_REPLACEMENT_DATA],
    YSI_g_sReplacePtr;

// New stuff.
stock _Hooks_AddReplacement(const longName[], const shortName[])
{
    // MAY need to strip spaces off the input strings, but I don't think so.
    if (YSI_g_sReplacePtr == MAX_HOOK_REPLACEMENTS)
    {
        P:E("Insufficient space in the replacements table.");
        return;
    }
    strcpy(YSI_g_sReplacements[YSI_g_sReplacePtr][E_HOOK_NAME_REPLACEMENT_SHORT], shortName, 4),
    strcpy(YSI_g_sReplacements[YSI_g_sReplacePtr][E_HOOK_NAME_REPLACEMENT_LONG] , longName , 16),
    YSI_g_sReplacements[YSI_g_sReplacePtr][E_HOOK_NAME_REPLACEMENT_MIN] = strlen(shortName),
    YSI_g_sReplacements[YSI_g_sReplacePtr][E_HOOK_NAME_REPLACEMENT_LEN] = strlen(longName),
    ++YSI_g_sReplacePtr;
}

public OnScriptInit()
{
    P:1("Hooks_OnScriptInit called");
    state _ALS : _ALS_go;
    // Get the replacements.
    new
        idx,
        ptr;
    // Loop over the redefinition functions and call them to have them call the
    // "_Hooks_AddReplacement" function above.  If we were being REALLY clever,
    // these functions could be removed from the public functions table
    // afterwards (there is already code in y_hooks for this) to reduce is size.
    while ((idx = AMX_GetPublicPointerPrefix(idx, ptr, _A<@_yH>)))
    {
        // From "amx\dynamic_call.inc" - check it is included in "y_hooks.inc".
        CallFunction(ptr);
    }
    Hooks_DoAllHooks();
    P:1("Hooks_OnScriptInit chain");
    // Dump the generated callbacks for debugging.
    //DisasmDump("YSI_TEST.asm");
    HookChain_OnScriptInit();
    P:1("Hooks_OnScriptInit end");
    return 1;
}