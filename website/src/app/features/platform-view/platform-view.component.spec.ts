import { ComponentFixture, TestBed } from '@angular/core/testing';

import { PlatformViewComponent } from './platform-view.component';

describe('PlatformViewComponent', () => {
  let component: PlatformViewComponent;
  let fixture: ComponentFixture<PlatformViewComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [PlatformViewComponent]
    })
      .compileComponents();

    fixture = TestBed.createComponent(PlatformViewComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component)
      .toBeTruthy();
  });
});
