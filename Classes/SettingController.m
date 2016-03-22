/*
 *  SettingController.m
 *
 *  Copyright 2008 Avérous Julien-Pierre
 *
 *  This file is part of ModSocks.
 *
 *  ModSocks is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  ModSocks is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with ModSocks.  If not, see <http://www.gnu.org/licenses/>.
 *
 */

#import "SettingController.h"
#import "FieldCell.h"
#import "SwitchCell.h"
#import "MSPrefs.h"

@implementation SettingController

#pragma mark TextField

// If the user press Done, hide the keyboard (by resigning first responder)
- (BOOL)textFieldShouldReturn:(UITextField *)theTextField
{
	[theTextField resignFirstResponder];
	return YES;
}

// Save the field text in the TableView
- (BOOL)textFieldShouldEndEditing:(UITextField *)textField
{
	UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];

	if ([cell isKindOfClass:[FieldCell class]] && [(FieldCell *)cell field] == textField)
		[[MSPrefs shared] setInt:[textField.text intValue] forKey:@"socks_port"];
	
	return YES;
}


#pragma mark SwitchCell

// Save the switch stat in the Tbale View
- (void)switchChanged:(UISwitch *)swtch
{
	UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:1 inSection:0]];

	if ([cell isKindOfClass:[SwitchCell class]] && [(SwitchCell *)cell uswitch] == swtch)
		[[MSPrefs shared] setBool:swtch.on forKey:@"socks_secure"];
}


#pragma mark TableView

- (NSInteger)numberOfSectionsInTableView:(UITableView *)aTableView
{
	return 1;
}

- (NSInteger)tableView:(UITableView *)aTableView numberOfRowsInSection:(NSInteger)section
{
	return 2;
}

- (UITableViewCell *)tableView:(UITableView *)aTableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	switch (indexPath.row)
	{
		case 0: // Port
		{
			FieldCell *cell = (FieldCell *)[aTableView dequeueReusableCellWithIdentifier:@"FieldCell"];
			
			cell.field.delegate = self;
			cell.label.text = @"Port";
			cell.field.text = [NSString stringWithFormat:@"%i", [[MSPrefs shared] getIntForKey:@"socks_port" def:8888]];
			cell.field.keyboardType = UIKeyboardTypeNumbersAndPunctuation;
			cell.field.returnKeyType = UIReturnKeyDone;
			
			return cell;
		}
			
		case 1: // Secure
		{
			SwitchCell *cell = (SwitchCell *)[aTableView dequeueReusableCellWithIdentifier:@"SwitchCell"];
			
			cell.label.text = @"Secure";
			
			cell.uswitch.on = [[MSPrefs shared] getBoolForKey:@"socks_secure" def:NO];
			[cell.uswitch addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
			
			cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
			
			return cell;
		}
	}
	
	
	UITableViewCell *def = [aTableView dequeueReusableCellWithIdentifier:@"DefCell"];
	
	if (!def)
		def = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"DefCell"] autorelease];
	
	def.textLabel.text = @"Default cell";
	
	return def;
}

- (NSString *)tableView:(UITableView *)aTableView titleForHeaderInSection:(NSInteger)section
{
	switch (section)
	{
		case 0:
			return @"Socks";
	}

	return @"Default";
}

- (void)tableView:(UITableView *)aTableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (indexPath.row == 1) // Secure row
		[self performSegueWithIdentifier:@"secure_edit" sender:self];
}

@end



@implementation SecureEditController


#pragma mark TextField

// If the user press Done, hide the keyboard (by resigning first responder)
- (BOOL)textFieldShouldReturn:(UITextField *)theTextField
{
	[theTextField resignFirstResponder];
	return YES;
}

// Save the field text in the TableView
- (BOOL)textFieldShouldEndEditing:(UITextField *)textField
{
	UITableViewCell *cell;
	
	cell = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
	if ([cell isKindOfClass:[FieldCell class]] && [(FieldCell *)cell field] == textField)
		[[MSPrefs shared] setString:textField.text forKey:@"socks_username"];
	
	cell = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:1 inSection:0]];
	if ([cell isKindOfClass:[FieldCell class]] && [(FieldCell *)cell field] == textField)
		[[MSPrefs shared] setString:textField.text forKey:@"socks_password"];
	
	return YES;
}


#pragma mark TableView

- (NSInteger)numberOfSectionsInTableView:(UITableView *)aTableView
{
	return 1;
}

- (NSInteger)tableView:(UITableView *)aTableView numberOfRowsInSection:(NSInteger)section
{
	return 2;
}

- (UITableViewCell *)tableView:(UITableView *)aTableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	switch (indexPath.row)
	{
		case 0: // User
		{
			FieldCell *cell = (FieldCell*)[aTableView dequeueReusableCellWithIdentifier:@"FieldCell"];
			
			if (cell == nil)
				cell = [[[FieldCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"FieldCell"] autorelease];
			
			cell.field.delegate = self;
			cell.label.text = @"Username";
			cell.field.text = [[MSPrefs shared] getStringForKey:@"socks_username" def:@"user"];
			cell.field.tag = (NSInteger)aTableView;
			cell.field.returnKeyType = UIReturnKeyDone;
			
			return cell;
		}
			
		case 1: // Password
		{
			FieldCell *cell = (FieldCell*)[aTableView dequeueReusableCellWithIdentifier:@"FieldCell"];
			
			if (cell == nil)
				cell = [[[FieldCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"FieldCell"] autorelease];
			
			cell.field.delegate = self;
			cell.label.text = @"Password";
			cell.field.text = [[MSPrefs shared] getStringForKey:@"socks_password" def:@"pass"];
			cell.field.tag = (NSInteger)aTableView;
			cell.field.returnKeyType = UIReturnKeyDone;
			cell.field.secureTextEntry = YES;
			
			return cell;
		}
	}
	
	
	UITableViewCell *def = [aTableView dequeueReusableCellWithIdentifier:@"DefCell"];
	
	if (!def)
		def = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"DefCell"] autorelease];
	
	def.textLabel.text = @"Default cell";
	
	return def;
}

- (NSString *)tableView:(UITableView *)aTableView titleForHeaderInSection:(NSInteger)section
{
	switch (section)
	{
		case 0:
			return @"Authentification";
	}
	
	return @"Default";
}

@end
