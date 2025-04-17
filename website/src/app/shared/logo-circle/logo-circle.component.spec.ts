import { ComponentFixture, TestBed } from '@angular/core/testing';

import { LogoCircleComponent } from './logo-circle.component';

describe('LogoCircleComponent', () => {
  let component: LogoCircleComponent;
  let fixture: ComponentFixture<LogoCircleComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [LogoCircleComponent]
    })
      .compileComponents();

    fixture = TestBed.createComponent(LogoCircleComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component)
      .toBeTruthy();
  });
});
