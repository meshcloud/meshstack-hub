import { TestBed } from '@angular/core/testing';

import { PlatformLogoService } from './platform-logo.service';

describe('PlatformLogoService', () => {
  let service: PlatformLogoService;

  beforeEach(() => {
    TestBed.configureTestingModule({});
    service = TestBed.inject(PlatformLogoService);
  });

  it('should be created', () => {
    expect(service)
      .toBeTruthy();
  });
});
