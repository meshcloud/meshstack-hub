import { CommonModule } from '@angular/common';
import { Component } from '@angular/core';

import { NavigationComponent } from '../navigation/navigation.component';

@Component({
  selector: 'app-header',
  imports: [CommonModule, NavigationComponent],
  templateUrl: './header.component.html',
  styleUrl: './header.component.scss',
  standalone: true
})
export class HeaderComponent {

}
