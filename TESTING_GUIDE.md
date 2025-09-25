# LECO Docket Tracker - Testing Strategy & Use Cases

## Overview

The LECO Docket Tracker is a work management system for Lanka Electricity Company that manages work dockets/assignments between managers and field technicians. This document outlines comprehensive use cases and testing strategies for the application.

## Application Features

- **User Authentication**: Login system with role-based access
- **Docket Management**: Create, assign, and track work dockets
- **Technician Portal**: View assigned work and complete tasks
- **Work Documentation**: Photo uploads and work logging
- **Staff Management**: Manage technician assignments and availability
- **Reporting**: Work completion summaries and statistics

## Use Cases

### Primary Actors

1. **Technicians** - Field workers who complete assigned dockets
2. **Managers/Supervisors** - Assign work and manage staff
3. **System Administrator** - Manage system users and configurations

### Core Use Cases

#### UC001: User Authentication

- **Actor:** All Users
- **Description:** Users log into the system with credentials
- **Preconditions:** User has valid credentials
- **Main Flow:**
  1. User enters username and password
  2. System validates credentials against database
  3. System identifies user role (technician/manager)
  4. User is redirected to appropriate dashboard
- **Alternative Flow:** Invalid credentials show error message
- **Postconditions:** User is authenticated and on their dashboard

#### UC002: View Available Dockets (Manager)

- **Actor:** Manager
- **Description:** Manager views all uploaded dockets waiting for assignment
- **Preconditions:** Manager is logged in
- **Main Flow:**
  1. Manager accesses docket management section
  2. System displays all unassigned dockets
  3. Manager can filter by depot, type, or upload date
  4. System shows docket details (type, depot, serial, upload time)
- **Postconditions:** Manager sees current docket status

#### UC003: Assign Docket to Technician

- **Actor:** Manager
- **Description:** Manager assigns a specific docket to an available technician
- **Preconditions:** Unassigned dockets exist, technicians are available
- **Main Flow:**
  1. Manager selects a docket from the list
  2. System displays docket details and assignment form
  3. System shows available technicians filtered by depot
  4. Manager selects technician and confirms assignment
  5. System updates docket status to "Assigned"
  6. System sends notification to technician
- **Alternative Flow:** No available technicians - show message
- **Postconditions:** Docket is assigned and technician is notified

#### UC004: View Assigned Dockets (Technician)

- **Actor:** Technician
- **Description:** Technician views their assigned work dockets
- **Preconditions:** Technician is logged in
- **Main Flow:**
  1. Technician accesses their portal
  2. System displays assigned dockets with priority order
  3. Technician can filter by status (assigned/in-progress/completed)
  4. System shows docket details and location information
- **Postconditions:** Technician sees their work queue

#### UC005: Start Work on Docket

- **Actor:** Technician
- **Description:** Technician begins work on an assigned docket
- **Preconditions:** Docket is assigned to technician
- **Main Flow:**
  1. Technician selects assigned docket
  2. System displays docket details and location
  3. Technician reviews work requirements
  4. Technician marks docket as "In Progress"
  5. System logs start time
- **Postconditions:** Docket status is "In Progress" with start time logged

#### UC006: Complete Docket Work

- **Actor:** Technician
- **Description:** Technician completes and submits work documentation
- **Preconditions:** Docket is in progress
- **Main Flow:**
  1. Technician accesses in-progress docket
  2. Technician takes completion photos
  3. Technician adds work descriptions and remarks
  4. Technician marks docket as completed
  5. System records completion time and updates status
  6. System notifies manager of completion
- **Alternative Flow:** Issues encountered - technician can add problem notes
- **Postconditions:** Docket is marked complete with documentation

#### UC007: Upload Work Photos

- **Actor:** Technician
- **Description:** Technician documents completed work with photos
- **Preconditions:** Camera access is available
- **Main Flow:**
  1. Technician accesses camera function in docket
  2. Technician takes photos of completed work
  3. Technician adds descriptions to photos
  4. System compresses and uploads photos
  5. Photos are linked to docket record
- **Alternative Flow:** Camera unavailable - show error message
- **Postconditions:** Work photos are stored with docket

#### UC008: View Work Summary

- **Actor:** Manager/Technician
- **Description:** Users view work completion statistics and reports
- **Preconditions:** User is logged in
- **Main Flow:**
  1. User accesses summary/reports section
  2. System calculates completion rates and statistics
  3. User can filter by time period, depot, or technician
  4. System displays charts and metrics
- **Postconditions:** User sees performance metrics

## Testing Strategy

### 1. Unit Tests

Test individual components in isolation:

#### Model Tests

- **Docket Model**: JSON serialization/deserialization, field validation
- **Worker Model**: Name formatting, availability status
- **WorkLog Model**: Time tracking, status updates
- **Assignment Model**: Relationship mapping

#### Service Tests

- **Authentication Service**: Login validation, token management
- **Docket Service**: CRUD operations, status updates
- **Photo Service**: Upload, compression, storage
- **Network Service**: API calls, error handling

### 2. Widget Tests

Test UI components and user interactions:

#### Page Tests

- **Login Page**: Form validation, error messages, loading states
- **Technician Portal**: Docket list display, filtering, navigation
- **Docket Details**: Information display, action buttons
- **Camera Screen**: Photo capture, preview, upload

#### Component Tests

- **Docket Card**: Information display, status indicators
- **Filter Widget**: Option selection, state management
- **Progress Indicator**: Loading states, completion status

### 3. Integration Tests

Test complete user workflows:

#### Technician Workflow

1. Login as technician
2. Navigate to portal
3. View assigned dockets
4. Start work on docket
5. Complete work with photos
6. Verify completion

#### Manager Workflow

1. Login as manager
2. View available dockets
3. Select technician
4. Assign docket
5. Verify assignment notification

#### Error Scenarios

- Invalid login credentials
- Network connectivity issues
- Camera access denied
- Server errors

### 4. Performance Tests

- App startup time
- Image upload speed
- Large dataset handling
- Memory usage monitoring

## Test Data Requirements

### Test Users

```
Managers:
- Username: manager01, Password: test123
- Username: supervisor01, Password: test123

Technicians:
- Username: tech01, Password: test123
- Username: tech02, Password: test123
```

### Test Dockets

```
- DKT001: Maintenance, Colombo Depot, High Priority
- DKT002: Installation, Kandy Depot, Medium Priority
- DKT003: Repair, Galle Depot, Low Priority
```

## Running Tests

### Prerequisites

1. Flutter SDK installed
2. Dependencies installed: `flutter pub get`
3. Test dependencies added to pubspec.yaml:
   ```yaml
   dev_dependencies:
     flutter_test:
       sdk: flutter
     mockito: ^5.4.0
     integration_test:
       sdk: flutter
   ```

### Commands

```bash
# Run all tests
flutter test

# Run unit tests only
flutter test test/models/
flutter test test/services/

# Run widget tests only
flutter test test/widgets/

# Run integration tests
flutter test integration_test/

# Run tests with coverage
flutter test --coverage
```

### Test File Structure

```
test/
├── models/
│   ├── docket_test.dart
│   ├── worker_model_test.dart
│   └── worklog_test.dart
├── services/
│   ├── docket_service_test.dart
│   └── auth_service_test.dart
├── widgets/
│   ├── login_page_test.dart
│   └── technician_portal_test.dart
└── test_helpers/
    └── mock_data.dart
integration_test/
└── app_test.dart
```

## Continuous Integration

### GitHub Actions Example

```yaml
name: Flutter Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: subosito/flutter-action@v2
      - run: flutter pub get
      - run: flutter test
      - run: flutter test integration_test/
```

## Test Coverage Goals

- **Unit Tests**: 90% code coverage
- **Widget Tests**: All major UI components
- **Integration Tests**: Critical user workflows
- **Performance Tests**: Key performance metrics

## Best Practices

1. **Test Naming**: Use descriptive test names that explain the scenario
2. **Test Structure**: Follow Arrange-Act-Assert pattern
3. **Mock Data**: Use realistic test data that matches production
4. **Error Handling**: Test both success and failure scenarios
5. **Isolation**: Each test should be independent and repeatable
6. **Documentation**: Comment complex test scenarios

## Maintenance

- Review and update tests when adding new features
- Maintain test data to reflect current business requirements
- Monitor test execution times and optimize slow tests
- Regular review of test coverage reports
