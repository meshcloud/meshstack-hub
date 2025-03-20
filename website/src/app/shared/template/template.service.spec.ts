import { TestBed } from '@angular/core/testing';

import { TemplateService } from './template.service';

describe('TemplateService', () => {
  let service: TemplateService;

  beforeEach(() => {
    TestBed.configureTestingModule({});
    service = TestBed.inject(TemplateService);
  });

  it('should be created', () => {
    expect(service)
      .toBeTruthy();
  });

  describe('filterTemplatesByPlatformType', () => {
    it('should return all templates when platformType is "all"', (done) => {
      const mockData = {
        templates: [
          { id: 1, platformType: 'aws' },
          { id: 2, platformType: 'azure' },
});
