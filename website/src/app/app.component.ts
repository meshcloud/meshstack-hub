import { CommonModule } from '@angular/common';
import { Component } from '@angular/core';
import { RouterOutlet } from '@angular/router';
import { NgbModule } from '@ng-bootstrap/ng-bootstrap';

import { HeaderComponent } from 'app/shared/header/header.component';

import { FooterComponent } from './shared/footer';

@Component({
  selector: 'app-root',
  imports: [CommonModule, RouterOutlet, HeaderComponent, FooterComponent, NgbModule],
  templateUrl: './app.component.html',
  standalone: true
})
export class AppComponent {

}
