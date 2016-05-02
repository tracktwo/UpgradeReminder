// UIUpgradeReminder
//
// Adds UI elements to the squad loadout screen to remind you of units that may use additional
// weapon attachments or PCS chips.

// Extend the UIScreenListener so we can keep track of which UI is visible. In this case we
// want to do stuff when the squad loadout screen is up. Configuration is done with the
// XComWeaponAttachmentReminder.ini file.
class UIUpgradeReminder extends UIScreenListener config(UpgradeReminder);

// Config variables for placement, size, and color of the weapon and PCS icons
var const config int WEAPON_X_POSITION;
var const config int WEAPON_Y_POSITION;
var const config float WEAPON_SCALE;
var const config String WEAPON_COLOR;

var const config int PCS_X_POSITION;
var const config int PCS_Y_POSITION;
var const config float PCS_SCALE;
var const config String PCS_COLOR;

// Lists of icons we're created. We create one icon for each member of the squad regardless
// of whether or not we're actually going to show it.
var array<UIPanel> WeaponIcons;
var array<UIPanel> PCSIcons;
var array<UISquadSelect_ListItem> CachedListItems;

// Destroy all current icons.
function DeleteAllIcons()
{
    local int i;

    `Log("+++ Destroying all icons");
    for (i = 0; i < WeaponIcons.Length; ++i) 
    {
        WeaponIcons[i].Remove();
    }

    for (i = 0; i < PCSIcons.Length; ++i) 
    {
        PCSIcons[i].Remove();
    }

    WeaponIcons.Length = 0;
    PCSIcons.Length = 0;
    CachedListItems.Length = 0;
}

// Hide all the icons
function HideAllIcons()
{
    local int i;

    `Log("+++ Hiding all icons");
    for (i = 0; i < WeaponIcons.Length; ++i) 
    {
        WeaponIcons[i].Hide();
    }

    for (i = 0; i < PCSIcons.Length; ++i) 
    {
        PCSIcons[i].Hide();
    }
}

// Create one weapon icon, parented to the given squad list item.
function UIImage CreateWeaponIcon(UISquadSelect_ListItem ListItem)
{
    local UIImage AttentionIcon;

    AttentionIcon = ListItem.DynamicContainer.Spawn(class 'UIImage', ListItem.DynamicContainer).InitImage(, 
        "img:///UICollection_UpgradeReminder.WeaponUpgrade");
    AttentionIcon.SetPosition(WEAPON_X_POSITION, WEAPON_Y_POSITION);
    AttentionIcon.SetScale(WEAPON_SCALE);
    AttentionIcon.SetColor(WEAPON_COLOR);
    AttentionIcon.Hide(); 
    return AttentionIcon;
}

// Create one PCS icon, parented to the given squad list item.
function UIImage CreatePCSIcon(UISquadSelect_ListItem ListItem)
{
    local UIImage PCSIcon;

    PCSIcon = ListItem.DynamicContainer.Spawn(class 'UIImage', ListItem.DynamicContainer).InitImage(, 
        "img:///UICollection_UpgradeReminder.CombatSim");
    PCSIcon.SetPosition(PCS_X_POSITION, PCS_Y_POSITION);
    PCSIcon.SetScale(PCS_SCALE);
    PCSIcon.SetColor(PCS_COLOR);
    PCSIcon.Hide(); 
    return PCSIcon;
}

// UI has started up: refresh our icon list
event OnInit(UIScreen Screen)
{
    local UISquadSelect SquadSelect;

    SquadSelect = UISquadSelect(Screen);
    if (SquadSelect != none)
        RefreshIcons(SquadSelect);
}

// Regained focus: refresh our icon list
event OnReceiveFocus(UIScreen Screen)
{
    local UISquadSelect SquadSelect;

    SquadSelect = UISquadSelect(Screen);
    if (SquadSelect != none)
        RefreshIcons(SquadSelect);
}

// Lost focus: Hide all the icons (likely unnecessary, as the parent panels hide
// themselves which cause all children to be hidden too.)
event OnLoseFocus(UIScreen Screen)
{
    local UISquadSelect SquadSelect;

    SquadSelect = UISquadSelect(Screen);
    if (SquadSelect != none)
        HideAllIcons();
}

// UI removed. Destroy all the icons.
event OnRemoved(UIScreen Screen)
{
    local UISquadSelect SquadSelect;

    SquadSelect = UISquadSelect(Screen);
    if (SquadSelect != none)
        DeleteAllIcons();
}

// Refresh the icon state
function RefreshIcons(UISquadSelect SquadSelect)
{
    local UISquadSelect_ListItem ListItem;
    local XComGameState_Unit Unit;
    local int i;
    local UIPanel Panel;
    local array<UIPanel> ListItemPanels;
    `Log("+++ Refreshing icons");

    // Iterate the children of the squad select looking for the list items.
    SquadSelect.GetChildrenOfType(class'UISquadSelect_ListItem', ListItemPanels);
    foreach ListItemPanels(Panel)
    {
        ListItem = UISquadSelect_ListItem(Panel);

        // Have we already handled this list item?
        i = CachedListItems.Find(ListItem);
        if (i == -1)
        {
            // This one is new. Create new icons and cache this item.
            WeaponIcons.AddItem(CreateWeaponIcon(ListItem));
            PCSIcons.AddItem(CreatePCSIcon(ListItem));
            CachedListItems.AddItem(ListItem);
            i = CachedListItems.Length - 1;
        }

        // Look up the unit associated with this slot.
        Unit = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(ListItem.GetUnitRef().ObjectID));

        // Now show or hide the icon depending on the availability of upgrades.
        if (ShouldShowWeaponUpgradeIcon(Unit))
        {
            WeaponIcons[i].Show();
        }
        else
        {
            WeaponIcons[i].Hide();
        }

        if (ShouldShowPCSIcon(Unit))
        {
            PCSIcons[i].Show();
        }
        else
        {
            PCSIcons[i].Hide();
        }
    }
}

// Determine whether or not to show the weapon upgrade for this unit. Fortunately there is a useful utility that
// already figures all this out for us: UIUtilities_Strategy.GetWeaponUpgradeAvailability().
function bool ShouldShowWeaponUpgradeIcon(XComGameState_Unit Unit)
{
    local TWeaponUpgradeAvailabilityData WeaponUpgradeAvailabilityData;

    class'UIUtilities_Strategy'.static.GetWeaponUpgradeAvailability(Unit, WeaponUpgradeAvailabilityData);

    return WeaponUpgradeAvailabilityData.bHasWeaponUpgrades &&
            WeaponUpgradeAvailabilityData.bHasWeaponUpgradeSlotsAvailable &&
            WeaponUpgradeAvailabilityData.bHasModularWeapons;
}

// Determine whether or not to show the PCS upgrade for this unit. Just like for weapons there is a utility
// that figures this out for us: UIUtilities_Strategy.GetPCSAvailability().
function bool ShouldShowPCSIcon(XComGameState_Unit Unit)
{
    local TPCSAvailabilityData PCSAvailabilityData;

    class 'UIUtilities_Strategy'.static.GetPCSAvailability(Unit, PCSAvailabilityData);

    // Return true if a) we have PCS implants in stock and b) the unit has an open PCS slot.
    return (PCSAvailabilityData.bHasNeurochipImplantsInInventory && PCSAvailabilityData.bHasCombatSimsSlotsAvailable);
}

defaultproperties
{
    // UISquadSelect is the name of the class we want to pay attention to, but it may be overridden by
    // another mod so we can't rely on it being there.
}
