/*
 *  FieldCell.m
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

#import "FieldCell.h"

@implementation FieldCell

@synthesize label;
@synthesize field;

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
	if (self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])
	{
		CGRect rectLabel = CGRectMake(10, 6, 100, 31);
		label = [[[UILabel alloc] initWithFrame:rectLabel] autorelease];
		[self.contentView addSubview:label];
		
		CGRect rectField = CGRectMake(rectLabel.size.width, 6, 180, 31);
		field = [[[UITextField alloc] initWithFrame:rectField] autorelease];
		[self.contentView addSubview:field];
		
		
		field.borderStyle = UITextBorderStyleRoundedRect;
		field.font = [UIFont systemFontOfSize:12];
		field.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
	}
	return self;
}


- (void)dealloc
{
	[super dealloc];
}


@end
