/*
 *  LabelCell.m
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

#import "LabelCell.h"

@implementation LabelCell

@synthesize label_l1;
@synthesize label_l2;

- (id)initWithFrame:(CGRect)frame reuseIdentifier:(NSString *)reuseIdentifier
{
	if (self = [super initWithFrame:frame reuseIdentifier:reuseIdentifier])
	{
		CGRect rectLabel1 = CGRectMake(10, 6, 100, 31);
		label_l1 = [[[UILabel alloc] initWithFrame:rectLabel1] autorelease];
		[self.contentView addSubview:label_l1];
		
		CGRect rectLabel2 = CGRectMake(rectLabel1.size.width, 6, 180, 31);
		label_l2 = [[[UILabel alloc] initWithFrame:rectLabel2] autorelease];
		[self.contentView addSubview:label_l2];
		
	}
	return self;
}


- (void)dealloc
{
	[super dealloc];
}


@end
