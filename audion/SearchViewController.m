//
//  SearchViewController.m
//  GooglePlacesAutocomplete
//
//  Created by Adam Cooper on 11/3/14.
//  Copyright (c) 2014 Adam Cooper. All rights reserved.
//


#import "SearchViewController.h"
#import "AUFonts.h"
#import "AUColors.h"
#import <CoreLocation/CoreLocation.h>
#import <MapKit/MapKit.h>
#import "TelescopeViewController.h"

@interface SearchViewController () 
@property (weak, nonatomic) IBOutlet UISearchBar *searchTextField;
@property NSMutableArray *pastSearchResults;
@property NSMutableArray *pastSearchWords;
@property NSMutableArray *localSearchQueries;
@property NSTimer *autoCompleteTimer;
@property NSString *substring;
@property CLLocationManager *locationManager;
@property (weak, nonatomic) IBOutlet UITableView *tableView;

@property (strong, nonatomic)MKMapView *mapView;

@end
NSString *const apiKey = @"AIzaSyCwBHH9Xa5Owjh4mGacgnkSh8KY9ewtcoU";

typedef NS_ENUM(NSUInteger, TableViewSection){
    TableViewSectionMain,
    TableViewSectionCount
};

@implementation SearchViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.searchTextField.barTintColor = [AUColors primaryColor];
    self.searchTextField.showsCancelButton = YES;
    
    [[UIBarButtonItem appearanceWhenContainedIn: [UISearchBar class], nil] setTintColor:[UIColor whiteColor]];
    self.localSearchQueries = [NSMutableArray array];
    self.pastSearchWords = [NSMutableArray array];
    self.pastSearchResults = [NSMutableArray array];
    self.searchTextField.delegate = self;
    [self createFooterViewForTable];
    
    self.searchTextField.searchBarStyle = UISearchBarStyleProminent;
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(dismissKeyboard)];
    //[self.view addGestureRecognizer:tap];
    
    self.mapView = [[MKMapView alloc]initWithFrame:CGRectMake(0, self.searchTextField.frame.origin.y + self.searchTextField.frame.size.height, self.view.frame.size.width, self.view.frame.size.height)];
    self.mapView.showsUserLocation = YES;
    self.mapView.userTrackingMode = MKUserTrackingModeFollow;
    
    self.tableView.delegate = self;
    self.tableView.backgroundColor = [UIColor colorWithRed:0.98 green:0.98 blue:0.98 alpha:1];
    //[self.view addSubview:self.mapView];
    
}

-(void)viewWillAppear:(BOOL)animated{
    
    [self.searchTextField becomeFirstResponder];
    [self.localSearchQueries removeAllObjects];
    [self.pastSearchResults removeAllObjects];
    [self.pastSearchWords removeAllObjects];
    [super viewWillAppear:animated];
    
}

- (void)dismissKeyboard
{
    [_searchTextField resignFirstResponder];
}

#pragma mark - Autocomplete SearchBar methods
-(void)searchBarSearchButtonClicked:(UISearchBar *)searchBar{
    
    [self.autoCompleteTimer invalidate];
    [self searchAutocompleteLocationsWithSubstring:self.substring];
    [self.searchTextField resignFirstResponder];
    [self.tableView reloadData];
}

-(void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText{
    
    NSString *searchWordProtection = [self.searchTextField.text stringByReplacingOccurrencesOfString:@" " withString:@""];
    NSLog(@"Length: %lu",(unsigned long)searchWordProtection.length);
    
    if (searchWordProtection.length != 0) {
        
        [self runScript];
        
    } else {
        NSLog(@"The searcTextField is empty.");
    }
}

-(BOOL)searchBar:(UISearchBar *)searchBar shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text{
    
    self.substring = [NSString stringWithString:self.searchTextField.text];
    self.substring= [self.substring stringByReplacingOccurrencesOfString:@" " withString:@"+"];
    self.substring = [self.substring stringByReplacingCharactersInRange:range withString:text];
    
    if ([self.substring hasPrefix:@"+"] && self.substring.length >1) {
        self.substring  = [self.substring substringFromIndex:1];
        NSLog(@"This string: %@ had a space at the begining.",self.substring);
    }
    
    
    return YES;
}


-(void)searchBarCancelButtonClicked:(UISearchBar *)searchBar{
    self.searchTextField.text = @"";
    [self.localSearchQueries removeAllObjects];
    [self.tableView reloadData];
    [self dismissViewControllerAnimated:YES completion:nil];
    [searchBar resignFirstResponder];
    
}

- (void)runScript{
    
    [self.autoCompleteTimer invalidate];
    self.autoCompleteTimer = [NSTimer scheduledTimerWithTimeInterval:0.65f
                                                              target:self
                                                            selector:@selector(searchAutocompleteLocationsWithSubstring:)
                                                            userInfo:nil
                                                             repeats:NO];
}


- (void)searchAutocompleteLocationsWithSubstring:(NSString *)substring
{
    [self.localSearchQueries removeAllObjects];
    [self.tableView reloadData];
    
    if (![self.pastSearchWords containsObject:self.substring]) {
        [self.pastSearchWords addObject:self.substring];
        NSLog(@"Search: %lu",(unsigned long)self.pastSearchResults.count);
        [self retrieveGooglePlaceInformation:self.substring withCompletion:^(NSArray * results) {
            [self.localSearchQueries addObjectsFromArray:results];
            NSDictionary *searchResult = @{@"keyword":self.substring,@"results":results};
            [self.pastSearchResults addObject:searchResult];
            [self.tableView reloadData];
            
        }];
        
    }else {
        
        for (NSDictionary *pastResult in self.pastSearchResults) {
            if([[pastResult objectForKey:@"keyword"] isEqualToString:self.substring]){
                [self.localSearchQueries addObjectsFromArray:[pastResult objectForKey:@"results"]];
                [self.tableView reloadData];
            }
        }
    }
}


#pragma mark - Google API Requests


-(void)retrieveGooglePlaceInformation:(NSString *)searchWord withCompletion:(void (^)(NSArray *))complete{
    NSString *searchWordProtection = [searchWord stringByReplacingOccurrencesOfString:@" " withString:@""];
    
    if (searchWordProtection.length != 0) {
        
        CLLocation *userLocation = self.locationManager.location;
        NSString *currentLatitude = @(userLocation.coordinate.latitude).stringValue;
        NSString *currentLongitude = @(userLocation.coordinate.longitude).stringValue;
        
        NSString *urlString = [NSString stringWithFormat:@"https://maps.googleapis.com/maps/api/place/autocomplete/json?input=%@&types=establishment|geocode&location=%@,%@&radius=500&language=en&key=%@",searchWord,currentLatitude,currentLongitude,apiKey];
        NSLog(@"AutoComplete URL: %@",urlString);
        NSURL *url = [NSURL URLWithString:[urlString stringByAddingPercentEscapesUsingEncoding: NSUTF8StringEncoding]];
        NSURLSessionConfiguration *defaultConfigObject = [NSURLSessionConfiguration defaultSessionConfiguration];
        NSURLSession *delegateFreeSession = [NSURLSession sessionWithConfiguration: defaultConfigObject delegate: nil delegateQueue: [NSOperationQueue mainQueue]];
        NSURLRequest *request = [NSURLRequest requestWithURL:url];
        NSURLSessionDataTask *task = [delegateFreeSession dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            NSDictionary *jSONresult = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:nil];
            NSArray *results = [jSONresult valueForKey:@"predictions"];
            
            if (error || [jSONresult[@"status"] isEqualToString:@"NOT_FOUND"] || [jSONresult[@"status"] isEqualToString:@"REQUEST_DENIED"]){
                if (!error){
                    NSDictionary *userInfo = @{@"error":jSONresult[@"status"]};
                    NSError *newError = [NSError errorWithDomain:@"API Error" code:666 userInfo:userInfo];
                    complete(@[@"API Error", newError]);
                    return;
                }
                complete(@[@"Actual Error", error]);
                return;
            }else{
                complete(results);
            }
        }];
        
        [task resume];
    }
    
}

-(void)retrieveJSONDetailsAbout:(NSString *)place withCompletion:(void (^)(NSArray *))complete {
    
    NSString *urlString = [NSString stringWithFormat:@"https://maps.googleapis.com/maps/api/place/details/json?placeid=%@&key=%@",place,apiKey];
    NSURL *url = [NSURL URLWithString:[urlString stringByAddingPercentEscapesUsingEncoding: NSUTF8StringEncoding]];
    NSURLSessionConfiguration *defaultConfigObject = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *delegateFreeSession = [NSURLSession sessionWithConfiguration: defaultConfigObject delegate: nil delegateQueue: [NSOperationQueue mainQueue]];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    NSURLSessionDataTask *task = [delegateFreeSession dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSDictionary *jSONresult = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:nil];
        NSArray *results = [jSONresult valueForKey:@"result"];
        
        if (error || [jSONresult[@"status"] isEqualToString:@"NOT_FOUND"] || [jSONresult[@"status"] isEqualToString:@"REQUEST_DENIED"]){
            if (!error){
                NSDictionary *userInfo = @{@"error":jSONresult[@"status"]};
                NSError *newError = [NSError errorWithDomain:@"API Error" code:666 userInfo:userInfo];
                complete(@[@"API Error", newError]);
                return;
            }
            complete(@[@"Actual Error", error]);
            return;
        }else{
            complete(results);
        }
    }];
    
    [task resume];
}




#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return TableViewSectionCount;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    //    return self.pastSearchQueries.count;
    switch (section) {
        case TableViewSectionMain:
            return self.localSearchQueries.count;
            break;
    }
    
    return 0;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    switch (indexPath.section) {
case TableViewSectionMain: {
    
            //this is where it broke
            NSDictionary *searchResult = [self.localSearchQueries objectAtIndex:indexPath.row];
            NSString *placeID = [searchResult objectForKey:@"place_id"];
            [self.searchTextField resignFirstResponder];
            [self retrieveJSONDetailsAbout:placeID withCompletion:^(NSArray *place) {
                
                self.selectedLocation = [[SelectedLocation alloc]init];
                self.selectedLocation.name = [place valueForKey:@"name"];
                self.selectedLocation.address = [place valueForKey:@"formatted_address"];
                NSString *latitude = [NSString stringWithFormat:@"%@,",[place valueForKey:@"geometry"][@"location"][@"lat"]];
                NSString *longitude = [NSString stringWithFormat:@"%@",[place valueForKey:@"geometry"][@"location"][@"lng"]];
                
                self.selectedLocation.locationCoordinates = CLLocationCoordinate2DMake(latitude.doubleValue, longitude.doubleValue);
                NSLog(@"Location Info: %@",self.selectedLocation);
                
                [self performSegueWithIdentifier:@"pickedLocation" sender:self];
                
                
            }];
        }break;
            
        default:
            break;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"SearchCell" forIndexPath:indexPath];
    switch (indexPath.section) {
        case TableViewSectionMain: {
            NSDictionary *searchResult = [self.localSearchQueries objectAtIndex:indexPath.row];
            cell.textLabel.text = [searchResult[@"terms"] objectAtIndex:0][@"value"];
            cell.detailTextLabel.text = searchResult[@"description"];
            
            cell.textLabel.font = [AUFonts interstateLightWithSize:16];
            cell.detailTextLabel.font = [AUFonts interstateLightWithSize:10];
        }break;
            
        default:
            break;
    }
    return cell;
}


- (void)createFooterViewForTable
{
    UIView *footerView  = [[UIView alloc] initWithFrame:CGRectMake(0, 500, 320, 70)];
    UIImageView *imageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"powered-by-google-on-white"]];
    imageView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    imageView.frame = CGRectMake(110,10,85,12);
    [footerView addSubview:imageView];
    self.tableView.tableFooterView = footerView;
}


#pragma mark - Segue

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([segue.identifier isEqualToString:@"pickedLocation"]) {
        
        TelescopeViewController *vc = (TelescopeViewController *)segue.destinationViewController;
        vc.location = self.selectedLocation;
        self.selectedLocation = nil;
    }
}

- (BOOL)shouldPerformSegueWithIdentifier:(NSString *)identifier sender:(id)sender
{
    if ([identifier isEqualToString:@"pickedLocation"]) {
        
        if (self.selectedLocation) {
            return YES;
        } else {
            return NO;
        }
        
    }
    
    return YES;
}
@end
