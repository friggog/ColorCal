#include <EventKit/EventKit.h>

@interface CompactMonthWeekView : UIView
@property BOOL compressedVerticalMode;
@property BOOL showWeekNumber;
@property (retain) NSArray *eventCounts;
+(CGFloat)eventMarkerDiameter:(BOOL)compact;
+(CGPoint)eventMarkerPositionForIndex:(int)a compressed:(BOOL)b showingOverlay:(BOOL)c showingWeekNumbers:(BOOL)d withBoundsWidth:(CGFloat)e;
+(UIColor *)eventMarkerColor;
// added
@property (retain) NSArray *coloredEventMarkers;
-(CALayer *)markerForEvent:(EKEvent *)event;
@end

@interface EKCalendarDate : NSObject
-(id)date;
@end

@interface CalendarModel : NSObject
@property (retain) NSSet *selectedCalendars;
@end

@interface UIApplication (cal)
@property (retain) CalendarModel *model;
@end

%hook CompactMonthWeekView

%property (nonatomic,retain) NSArray *coloredEventMarkers;

-(void)setEventCounts:(NSArray*)eventCounts animated:(BOOL)a {
	BOOL hasChanged = ![self.eventCounts isEqualToArray:eventCounts];
	%orig;
	if(hasChanged) {
		NSDate *weekStartDate = MSHookIvar<EKCalendarDate*>(self,"_startCalendarDate").date;
		NSDate *weekEndDate = MSHookIvar<EKCalendarDate*>(self,"_endCalendarDate").date;

		EKEventStore *store = [[EKEventStore alloc] init];
		NSPredicate *predicate = [store predicateForEventsWithStartDate:weekStartDate
																endDate:weekEndDate
															  calendars:[[UIApplication sharedApplication].model.selectedCalendars allObjects]];
		NSArray *allEvents = [store eventsMatchingPredicate:predicate];
		[store release];

		NSMutableArray *allDayEventsThisWeek = [[NSMutableArray alloc] init];
		NSMutableArray *shortEventsThisWeek = [[NSMutableArray alloc] init];
		for(EKEvent *e in allEvents) {
			if(e.allDay)
				[allDayEventsThisWeek addObject:e];
			else
				[shortEventsThisWeek addObject:e];
		}

		CGFloat markerSeparation = [%c(CompactMonthWeekView) eventMarkerDiameter:YES] + 2; // self.compressedVerticalMode

		NSMutableArray *eventMarkers = [[NSMutableArray alloc] init];
		int currentIndexInShortEventArray = 0;
		for(int dayIndex = 0; dayIndex<self.eventCounts.count; dayIndex++) {
			int eventsThisDay = [self.eventCounts[dayIndex] integerValue];
			int eventsLeftThisDay = eventsThisDay;
			CALayer *thisDayEventMarker = [CALayer layer];
			int currentEventThisDayIndex = 0;
			for(EKEvent *event in allDayEventsThisWeek) {
				NSDate *thisDayDate = [weekStartDate dateByAddingTimeInterval:60*60*24*dayIndex];
				NSCalendar *cal = MSHookIvar<NSCalendar *>(self,"_calendar");
				if([cal isDate:thisDayDate inSameDayAsDate:event.startDate] ||
				   [cal isDate:thisDayDate inSameDayAsDate:event.endDate] ||
				   ([thisDayDate compare:event.startDate] == NSOrderedDescending &&
				      [thisDayDate compare:event.endDate] == NSOrderedAscending)) {
					// all day event is on this day
					CALayer *marker = [self markerForEvent:event];
					marker.position = CGPointMake(((currentEventThisDayIndex - (eventsThisDay/2.0)) * markerSeparation) + 4,2);
					[thisDayEventMarker addSublayer:marker];
					eventsLeftThisDay--;
					currentEventThisDayIndex++;
				}
			}
			for(int i = currentIndexInShortEventArray; i < currentIndexInShortEventArray + eventsLeftThisDay; i++) {
				EKEvent *event = NULL;
				if(i < shortEventsThisWeek.count)
					event = shortEventsThisWeek[i];
				CALayer *marker = [self markerForEvent:event];
				marker.position = CGPointMake(((currentEventThisDayIndex - (eventsThisDay/2.0)) * markerSeparation) + 4,2);
				[thisDayEventMarker addSublayer:marker];
				currentEventThisDayIndex++;
			}
			currentIndexInShortEventArray += eventsLeftThisDay;
			[eventMarkers addObject:thisDayEventMarker];
		}

		[allDayEventsThisWeek release];
		[shortEventsThisWeek release];

		for(CALayer *marker in self.coloredEventMarkers) {
			[marker removeFromSuperlayer];
		}

		NSArray *currEventMarkers = MSHookIvar<NSArray*>(self,"_eventMarkers");
		for(int k=0; k<currEventMarkers.count; k++) {
			CALayer *currLayer = currEventMarkers[k];
			if(k<eventMarkers.count) {
				CALayer *newLayer = eventMarkers[k];
				newLayer.position = currLayer.position;
				[currLayer.superlayer addSublayer:newLayer];
			}
			[currLayer removeFromSuperlayer];
		}

		self.coloredEventMarkers = [eventMarkers copy];
		[eventMarkers release];
	}
	else {
		NSArray *currEventMarkers = MSHookIvar<NSArray*>(self,"_eventMarkers");
		for(int k=0; k<currEventMarkers.count; k++) {
			CALayer *currLayer = currEventMarkers[k];
			if(k<self.coloredEventMarkers.count) {
				CALayer *newLayer = self.coloredEventMarkers[k];
				newLayer.position = currLayer.position;
			}
			[currLayer removeFromSuperlayer];
		}

	}
}

-(void)dealloc {
	[self.coloredEventMarkers release];
	%orig;
}

%new -(CALayer *)markerForEvent:(EKEvent *)event {
	CALayer *marker = [CALayer layer];
	if(event)
		marker.backgroundColor = event.calendar.CGColor;
	else
		marker.backgroundColor = [%c(CompactMonthWeekView) eventMarkerColor].CGColor;
	CGFloat diameter = [%c(CompactMonthWeekView) eventMarkerDiameter:YES]; // self.compressedVerticalMode
	marker.frame = CGRectMake(0,0,diameter,diameter);
	marker.cornerRadius = diameter/2;
	marker.masksToBounds = YES;
	return marker;
}

%end
