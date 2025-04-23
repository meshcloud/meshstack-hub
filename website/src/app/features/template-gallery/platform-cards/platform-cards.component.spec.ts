import { ComponentFixture, TestBed } from '@angular/core/testing';
import { By } from '@angular/platform-browser';
import { RouterTestingModule } from '@angular/router/testing';

import { PlatformCardsComponent } from './platform-cards.component';


describe('NavigationComponent', () => {
  let component: PlatformCardsComponent;
  let fixture: ComponentFixture<PlatformCardsComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [PlatformCardsComponent, RouterTestingModule]
    })
      .compileComponents();

    fixture = TestBed.createComponent(PlatformCardsComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should highlight the active tab based on activeTab property', () => {
    component.activeTab = 'AWS';
    fixture.detectChanges();

    const activeTab = fixture.debugElement.query(By.css('.nav-link.active'));
    expect(activeTab.nativeElement.textContent.trim())
      .toBe('AWS');
  });

  it('should have correct routerLink for each tab', () => {
    const links = fixture.debugElement.queryAll(By.css('.nav-link'));
    expect(links[0].attributes['ng-reflect-router-link'])
      .toBe('/all');
    expect(links[1].attributes['ng-reflect-router-link'])
      .toBe('/aws');
    expect(links[2].attributes['ng-reflect-router-link'])
      .toBe('/azure');
    expect(links[3].attributes['ng-reflect-router-link'])
      .toBe('/gcp');
  });
});
