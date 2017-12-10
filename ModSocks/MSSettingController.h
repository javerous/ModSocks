/*
 *  SettingController.h
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

#import <UIKit/UIKit.h>


NS_ASSUME_NONNULL_BEGIN


/*
** MSSettingController
*/
#pragma mark - MSSettingController

@interface MSSettingController : UITableViewController <UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate>

@end


/*
** MSSecureEditController
*/
#pragma mark - MSSecureEditController

@interface MSSecureEditController : UITableViewController <UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate>

@end


NS_ASSUME_NONNULL_END

