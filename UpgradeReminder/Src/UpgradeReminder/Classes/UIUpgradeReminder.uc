// UIUpgradeReminder
//
// Adds UI elements to the squad loadout screen to remind you of units that may use additional
// weapon attachments or PCS chips.

// Extend the UIScreenListener so we can keep track of which UI is visible. In this case we
// want to do stuff when the squad loadout screen is up. Configuration is done with the
// XComWeaponAttachmentReminder.ini file.
class UIUpgradeReminder extends UIScreenListener config(UpgradeReminder);

// Struct defining which upgrades can replace another upgrade. If a weapon has 'UpgradeName'
// equipped and one of the upgrades in 'ReplacedBy' is available in the inventory, an upgrade
// icon will be shown even if there are no free slots on the weapon.
struct WeaponUpgradeChain
{
    var Name UpgradeName;
    var array<Name> ReplacedBy;
};

const WeaponIconName = 'UR_WeaponIcon';
const PCSIconName = 'UR_PCSIcon';

// Config variables for placement, size, and color of the weapon and PCS icons
var const config int WEAPON_X_POSITION;
var const config int WEAPON_Y_POSITION;
var const config int WOTC_WEAPON_X_POSITION;
var const config int WOTC_WEAPON_Y_POSITION;
var const config float WEAPON_SCALE;
var const config String WEAPON_COLOR;

var const config int PCS_X_POSITION;
var const config int PCS_Y_POSITION;
var const config int WOTC_PCS_X_POSITION;
var const config int WOTC_PCS_Y_POSITION;
var const config float PCS_SCALE;
var const config String PCS_COLOR;

// Config variable outlining which upgrades replace which other ones.
var config array<WeaponUpgradeChain> WeaponUpgradeChains;

// Cached copy of template names for items we have in inventory.
var array<Name> AvailableUpgrades;

// Try to detect if we're running in vanilla XCOM2 or War of the Chosen in a way
// that won't break in vanilla. The main problem is the positioning of the icons,
// because the soldier bond icon is using the same location historically used for
// the PCS icon.
//
// Just check to see if there is a child named 'bondIconMC' somewhere under the list
// item. If so, this is probably WotC (unless someone makes a vanilla XCOM2 mod that
// adds a child with this name). This is a recursive search so it should work fine
// even if UISquadSelect_ListItem is overridden as long as the overriding class
// inherits from it.
function bool DetectWotc(UISquadSelect_ListItem ListItem)
{
	return ListItem.GetChildByName('bondIconMC', false) != none;
}

// Create one weapon icon, parented to the given squad list item.
function UIImage CreateWeaponIcon(UISquadSelect_ListItem ListItem)
{
    local UIImage AttentionIcon;

    AttentionIcon = ListItem.DynamicContainer.Spawn(class 'UIImage', ListItem.DynamicContainer).InitImage(WeaponIconName,
        "img:///UICollection_UpgradeReminder.WeaponUpgrade");
    AttentionIcon.SetPosition(DetectWotc(ListItem) ? WOTC_WEAPON_X_POSITION : WEAPON_X_POSITION, WEAPON_Y_POSITION);
    AttentionIcon.SetScale(WEAPON_SCALE);
    AttentionIcon.SetColor(WEAPON_COLOR);
    AttentionIcon.Hide();
    return AttentionIcon;
}

// Create one PCS icon, parented to the given squad list item.
function UIImage CreatePCSIcon(UISquadSelect_ListItem ListItem)
{
    local UIImage PCSIcon;

    PCSIcon = ListItem.DynamicContainer.Spawn(class 'UIImage', ListItem.DynamicContainer).InitImage(PCSIconName,
        "img:///UICollection_UpgradeReminder.CombatSim");
    PCSIcon.SetPosition(DetectWotc(ListItem) ? WOTC_PCS_X_POSITION : PCS_X_POSITION, PCS_Y_POSITION);
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
    {
        // We have a squad select UI. But don't refresh the icons immediately as this can occasionally
        // cause graphical issues.
        SquadSelect.SetTimer(1.0f, false, 'DelayedRefresh', self);
    }
}

function DelayedRefresh()
{
    local UISquadSelect SquadSelect;

    // Make sure we still have a squad select somewhere in our stack.
    SquadSelect = UISquadSelect(`SCREENSTACK.GetFirstInstanceOf(class'UISquadSelect'));
    if (SquadSelect != none)
    {
        RefreshAvailableUpgrades();
        RefreshIcons(SquadSelect);
    }
}

// Regained focus: refresh our icon list
event OnReceiveFocus(UIScreen Screen)
{
    local UISquadSelect SquadSelect;

    SquadSelect = UISquadSelect(Screen);
    if (SquadSelect != none)
    {
        RefreshAvailableUpgrades();
        RefreshIcons(SquadSelect);
    }
}

function RefreshUnitIcon(UISquadSelect_ListItem ListItem, bool Show, name IconName)
{
	local UIImage Image;

	Image = UIImage(ListItem.DynamicContainer.GetChildByName(IconName, false));
	if (Show)
	{
		if (Image == none)
		{
			Image = (IconName == WeaponIconName) ? CreateWeaponIcon(ListItem) : CreatePCSIcon(ListItem);
		}
		Image.Show();
	}
	else if (Image != none)
	{
		Image.Hide();
	}
}

// Refresh the icon state
function RefreshIcons(UISquadSelect SquadSelect)
{
    local UISquadSelect_ListItem ListItem;
    local XComGameState_Unit Unit;
    local UIPanel Panel;
    local array<UIPanel> ListItemPanels;

    // Iterate the children of the squad select looking for the list items.
    SquadSelect.GetChildrenOfType(class'UISquadSelect_ListItem', ListItemPanels);
    foreach ListItemPanels(Panel)
    {
        ListItem = UISquadSelect_ListItem(Panel);

        // Look up the unit associated with this slot.
        Unit = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(ListItem.GetUnitRef().ObjectID));

        // Now show or hide the icon depending on the availability of upgrades.
        RefreshUnitIcon(ListItem, ShouldShowWeaponUpgradeIcon(Unit), WeaponIconName);
		RefreshUnitIcon(ListItem, ShouldShowPCSIcon(Unit), PCSIconName);
    }
}

function RefreshAvailableUpgrades()
{
    local array<XComGameState_Item> AllUpgradeItems;
    local XComGameState_Item Item;
    local XComGameState_HeadquartersXCom XComHQ;

    XComHQ = class'UIUtilities_Strategy'.static.GetXComHQ();
    AllUpgradeItems = XComHQ.GetAllWeaponUpgradesInInventory();

    AvailableUpgrades.Length = 0;

    foreach AllUpgradeItems(Item)
    {
        if (AvailableUpgrades.Find(Item.GetMyTemplateName()) == -1)
        {
            AvailableUpgrades.AddItem(Item.GetMyTemplateName());
        }
    }
}

// Given the list of equipped upgrades on a weapon and the list of available upgrade names in the inventory,
// return true if any of the avilable upgrades is a more advanced version of one on the weapon.
function bool CanImproveUpgrade(out array<Name> EquippedUpgrades)
{
    local int EquippedIdx;
    local int UpgradeIdx;
    local Name UpgradeName;

    for (EquippedIdx = 0; EquippedIdx < EquippedUpgrades.Length; ++EquippedIdx)
    {
        UpgradeIdx = WeaponUpgradeChains.Find('UpgradeName', EquippedUpgrades[EquippedIdx]);
        if (UpgradeIdx >= 0)
        {
            foreach WeaponUpgradeChains[UpgradeIdx].ReplacedBy(UpgradeName)
            {
                if (AvailableUpgrades.Find(UpgradeName) >= 0)
                {
                    return true;
                }
            }
        }
    }

    return false;
}

function bool HasUpgradeNotOnWeapon(out array<Name> EquippedUpgrades)
{
    local Name Upgrade;

    foreach AvailableUpgrades(Upgrade)
    {
        if (EquippedUpgrades.Find(Upgrade) == -1)
        {
            return true;
        }
    }

    return false;
}

// Determine whether or not to show the weapon upgrade for this unit. Fortunately there is a useful utility that
// already figures all this out for us: UIUtilities_Strategy.GetWeaponUpgradeAvailability().
function bool ShouldShowWeaponUpgradeIcon(XComGameState_Unit Unit)
{
    local TWeaponUpgradeAvailabilityData WeaponUpgradeAvailabilityData;
    local array<Name> EquippedUpgrades;

    class'UIUtilities_Strategy'.static.GetWeaponUpgradeAvailability(Unit, WeaponUpgradeAvailabilityData);

    // If we don't have modular weapons researched or any available upgrades, there is nothing to show.
    if (!WeaponUpgradeAvailabilityData.bHasWeaponUpgrades || !WeaponUpgradeAvailabilityData.bHasModularWeapons)
    {
        return false;
    }

    EquippedUpgrades = Unit.GetPrimaryWeapon().GetMyWeaponUpgradeTemplateNames();

    // We should show the upgrade icon if we have an upgrade available that is a higher tier version of one we already
    // have installed (regardless of whether we have free slots).
    if (CanImproveUpgrade(EquippedUpgrades))
    {
        return true;
    }

    // Otherwise if we have an available slot AND an available weapon upgrade that isn't the same as one of our existing ones
    // we can upgrade.
    return WeaponUpgradeAvailabilityData.bHasWeaponUpgradeSlotsAvailable && HasUpgradeNotOnWeapon(EquippedUpgrades);
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
